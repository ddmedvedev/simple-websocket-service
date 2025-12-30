import os
import asyncio
import logging
import tempfile
from datetime import datetime
from starlette.applications import Starlette
from starlette.websockets import WebSocket, WebSocketDisconnect
from starlette.routing import WebSocketRoute, Route
from starlette.responses import JSONResponse
from openai import OpenAI
import boto3

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
S3_BUCKET = os.getenv("S3_BUCKET")

# Accumulate chunks before transcription (every N chunks)
CHUNKS_PER_TRANSCRIPTION = 10

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("WebSocket connection accepted")

    audio_chunks = []
    chunk_buffer = []
    chunk_count = 0
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    s3_key = f"audio_{timestamp}.wav"
    full_transcription = []
    s3_client = boto3.client('s3') if S3_BUCKET else None

    try:
        await websocket.send_json({"type": "status", "message": "Connected. Send audio chunks."})
        logger.info("Connection message sent to client")

        while True:
            # Receive audio chunk
            message = await websocket.receive()

            if "bytes" in message:
                audio_data = message["bytes"]
                audio_chunks.append(audio_data)
                chunk_buffer.append(audio_data)
                chunk_count += 1

                logger.info(f"Received chunk {chunk_count} ({len(audio_data)} bytes)")

                # Transcribe every N chunks (using ALL accumulated audio from start)
                if chunk_count % CHUNKS_PER_TRANSCRIPTION == 0:
                    try:
                        # Combine ALL chunks received so far (includes WAV header from chunk 1)
                        combined_audio = b''.join(audio_chunks)

                        # Save combined chunks to temp file
                        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                            tmp.write(combined_audio)
                            temp_file_path = tmp.name

                        logger.info(f"Transcribing accumulated chunks 1-{chunk_count} (total: {len(combined_audio)} bytes)")

                        # Transcribe with OpenAI Whisper
                        with open(temp_file_path, "rb") as audio_file:
                            response = client.audio.transcriptions.create(
                                model="whisper-1",
                                file=audio_file,
                                response_format="text"
                            )

                        # Clean up temp file
                        os.unlink(temp_file_path)

                        if response:
                            transcription_text = response.strip()

                            # Only send the new part if we have previous transcriptions
                            if full_transcription:
                                # Send incremental update (new text only)
                                previous_text = " ".join(full_transcription)
                                if transcription_text.startswith(previous_text):
                                    new_text = transcription_text[len(previous_text):].strip()
                                else:
                                    new_text = transcription_text
                            else:
                                new_text = transcription_text

                            full_transcription = [transcription_text]  # Store complete transcription

                            logger.info(f"Transcription result (chunks 1-{chunk_count}): {transcription_text}")
                            logger.info(f"New text: {new_text}")

                            await websocket.send_json({
                                "type": "transcription",
                                "text": new_text,
                                "full_text": transcription_text,
                                "chunk_range": f"1-{chunk_count}"
                            })

                    except Exception as e:
                        error_msg = f"Transcription error: {str(e)}"
                        logger.error(error_msg)
                        await websocket.send_json({
                            "type": "error",
                            "message": error_msg
                        })

            elif "text" in message:
                text = message["text"]
                if text == "END":
                    logger.info("Received END signal")

                    # Upload audio to S3
                    s3_location = None
                    if s3_client and S3_BUCKET and audio_chunks:
                        combined_audio = b''.join(audio_chunks)
                        s3_client.put_object(
                            Bucket=S3_BUCKET,
                            Key=s3_key,
                            Body=combined_audio,
                            ContentType="audio/wav"
                        )
                        s3_location = f"s3://{S3_BUCKET}/{s3_key}"
                        logger.info(f"Audio uploaded to {s3_location}")

                    # Use the last transcription from chunks (no additional API call)
                    complete_transcription = full_transcription[0] if full_transcription else ""

                    logger.info(f"=== COMPLETE TRANSCRIPTION ===")
                    logger.info(f"{complete_transcription}")
                    logger.info(f"Total chunks processed: {chunk_count}")
                    logger.info(f"==============================")

                    await websocket.send_json({
                        "type": "complete",
                        "message": f"Audio saved to {s3_location}" if s3_location else "Audio not saved (S3 not configured)",
                        "full_transcription": complete_transcription,
                        "total_chunks": chunk_count
                    })
                    break

    except WebSocketDisconnect:
        logger.warning("WebSocket disconnected")

    except Exception as e:
        error_msg = f"Server error: {str(e)}"
        logger.error(error_msg)
        try:
            await websocket.send_json({
                "type": "error",
                "message": error_msg
            })
        except:
            pass  # WebSocket might already be closed

    finally:
        try:
            await websocket.close()
        except:
            pass  # WebSocket might already be closed

        logger.info("WebSocket connection closed")


async def health_check(request):
    return JSONResponse({"status": "ok"})


app = Starlette(
    routes=[
        Route("/health", health_check),
        WebSocketRoute("/ws", websocket_endpoint),
    ]
)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
