import json
import time
from channels.generic.websocket import AsyncWebsocketConsumer
from django.utils import timezone


class SupportChatConsumer(AsyncWebsocketConsumer):
    """
    Django Channels WebSocket Consumer for Live Support Chat.
    ws://.../ws/support/?phone=...&name=...
    """

    async def connect(self):
        query_string = self.scope.get("query_string", b"").decode("utf-8")
        params = dict(q.split("=") for q in query_string.split("&") if "=" in q)
        
        self.phone = params.get("phone", "").strip()
        self.user_name = params.get("name", "Customer").strip()
        self.clean_phone = self.phone.replace("+91", "").replace(" ", "").replace("-", "") or "anonymous"
        self.room_group_name = f"support_chat_{self.clean_phone}"

        # Join Redis Channel Layer group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )

        await self.accept()

        # Send welcome connection confirmation
        await self.send(text_data=json.dumps({
            "type": "connection_established",
            "message": "Connected to MilkDrop Live Redis Support Gateway ⚡",
            "room": self.room_group_name,
        }))

    async def disconnect(self, close_code):
        # Leave Redis Channel Layer group
        if hasattr(self, "room_group_name"):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            text = data.get("text", "").strip()
            sender_name = data.get("sender_name", self.user_name)
            sender_type = data.get("sender_type", "user")
            order_id = data.get("order_id")

            if not text:
                return

            msg_payload = {
                "id": f"msg_{int(time.time() * 1000)}",
                "sender_type": sender_type,
                "sender_name": sender_name,
                "text": text,
                "order_id": order_id,
                "timestamp": timezone.now().isoformat(),
            }

            # Broadcast to Redis group
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "chat_message",
                    "payload": msg_payload,
                }
            )
        except Exception:
            pass

    async def chat_message(self, event):
        payload = event["payload"]
        await self.send(text_data=json.dumps(payload))

    async def typing_event(self, event):
        await self.send(text_data=json.dumps({
            "type": "typing",
            "is_typing": event.get("is_typing", True),
        }))
