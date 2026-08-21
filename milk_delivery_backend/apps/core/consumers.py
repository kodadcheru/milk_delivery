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


class HubRealtimeConsumer(AsyncWebsocketConsumer):
    """
    Django Channels Redis WebSocket Consumer for Live Hub Operations & Real-Time Sync.
    ws://.../ws/hub/<hub_code>/ or ws://.../ws/hub/
    """

    async def connect(self):
        hub_code = self.scope.get("url_route", {}).get("kwargs", {}).get("hub_code")
        if not hub_code:
            query_string = self.scope.get("query_string", b"").decode("utf-8")
            params = dict(q.split("=") for q in query_string.split("&") if "=" in q)
            hub_code = params.get("hub_code", "HUB-KDD-01")

        self.hub_code = hub_code.strip().upper()
        self.room_group_name = f"hub_{self.hub_code}"
        self.all_hubs_group = "hub_all"

        # Join Redis Channel Layer group for this specific hub
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name,
        )
        # Also join global hub broadcast group
        await self.channel_layer.group_add(
            self.all_hubs_group,
            self.channel_name,
        )

        await self.accept()

        # Send confirmation of active Redis connection
        await self.send(text_data=json.dumps({
            "type": "connection_established",
            "message": f"Connected to Live Redis Hub Stream for {self.hub_code} ⚡",
            "hub_code": self.hub_code,
            "timestamp": timezone.now().isoformat(),
        }))

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name"):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )
        if hasattr(self, "all_hubs_group"):
            await self.channel_layer.group_discard(
                self.all_hubs_group,
                self.channel_name,
            )

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            action = data.get("action", "ping")

            if action == "ping":
                await self.send(text_data=json.dumps({
                    "type": "pong",
                    "timestamp": timezone.now().isoformat(),
                    "hub_code": getattr(self, "hub_code", "HUB-KDD-01"),
                }))
            elif action == "broadcast_alert":
                msg = data.get("message", "")
                if msg:
                    await self.channel_layer.group_send(
                        self.room_group_name,
                        {
                            "type": "hub_event",
                            "payload": {
                                "type": "hub_broadcast",
                                "hub_code": self.hub_code,
                                "message": msg,
                                "timestamp": timezone.now().isoformat(),
                            }
                        }
                    )
        except Exception:
            pass

    async def hub_event(self, event):
        payload = event.get("payload", {})
        await self.send(text_data=json.dumps(payload))


def broadcast_hub_event(hub_code, event_type, data=None):
    """
    Synchronous helper to broadcast real-time events to Redis channel layers.
    Can be called from Django views, signals, or tasks.
    """
    try:
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        if not channel_layer:
            return

        clean_code = (hub_code or "HUB-KDD-01").strip().upper()
        payload = {
            "type": "hub_event",
            "event_type": event_type,
            "hub_code": clean_code,
            "data": data or {},
            "timestamp": timezone.now().isoformat(),
        }

        async_to_sync(channel_layer.group_send)(
            f"hub_{clean_code}",
            {"type": "hub_event", "payload": payload}
        )
        async_to_sync(channel_layer.group_send)(
            "hub_all",
            {"type": "hub_event", "payload": payload}
        )
    except Exception:
        pass

