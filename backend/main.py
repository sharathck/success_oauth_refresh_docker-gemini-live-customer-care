import asyncio
import json
import os

import websockets
from websockets.legacy.protocol import WebSocketCommonProtocol
from websockets.legacy.server import WebSocketServerProtocol
from auth import ServiceAccountAuth

HOST = "us-central1-aiplatform.googleapis.com"
SERVICE_URL = f"wss://{HOST}/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent"

DEBUG = False

auth_service = ServiceAccountAuth()


async def proxy_task(
    client_websocket: WebSocketCommonProtocol, server_websocket: WebSocketCommonProtocol
) -> None:
    """
    Forwards messages from one WebSocket connection to another.

    Args:
        client_websocket: The WebSocket connection from which to receive messages.
        server_websocket: The WebSocket connection to which to send messages.
    """
    async for message in client_websocket:
        try:
            print("proxying: ", message)
            data = json.loads(message)
            print("proxying data: ", data)
            if DEBUG:
                print("proxying: ", data)
            await server_websocket.send(json.dumps(data))
        except Exception as e:
            print(f"Error processing message: {e}")

    await server_websocket.close()


async def create_proxy(
    client_websocket: WebSocketCommonProtocol
) -> None:
    """
    Establishes a WebSocket connection to the server and creates two tasks for
    bidirectional message forwarding between the client and the server.

    Args:
        client_websocket: The WebSocket connection of the client.
    """
    
    bearer_token = auth_service.get_access_token()
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {bearer_token}",
    }

    async with websockets.connect(
        SERVICE_URL, extra_headers=headers
    ) as server_websocket:
        client_to_server_task = asyncio.create_task(
            proxy_task(client_websocket, server_websocket)
        )
        server_to_client_task = asyncio.create_task(
            proxy_task(server_websocket, client_websocket)
        )
        await asyncio.gather(client_to_server_task, server_to_client_task)


async def handle_client(client_websocket: WebSocketServerProtocol) -> None:
    """
    Handles a new client connection and establishes a proxy connection to the server.

    Args:
        client_websocket: The WebSocket connection of the client.
    """
    print("New connection...")
    
    try:
        await create_proxy(client_websocket)
    except Exception as e:
        print(f"Error creating proxy: {e}")
        await client_websocket.close(code=1011, reason="Internal server error")


async def main() -> None:
    """
    Starts the WebSocket server and listens for incoming client connections.
    """
    async with websockets.serve(handle_client, "localhost", 8080):
        print("Running websocket server localhost:8080...")
        # Run forever
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
