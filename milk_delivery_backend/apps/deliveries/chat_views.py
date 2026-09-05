from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.core.cache import cache
from .models import DeliveryChatMessage, DeliveryTask, LiveOrder


def _get_delivery_chat_cache_key(channel_key):
    return f"deliv_chat_{channel_key}"


def _is_user_authorized_for_chat(user, task_obj=None, order_obj=None, channel_key=""):
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser or user.is_staff or getattr(user, "role", "") in ("ADMIN", "STAFF"):
        return True
    
    if task_obj:
        if getattr(task_obj, "target_customer", None) == user or task_obj.driver == user:
            return True
        if task_obj.hub and getattr(user, "assigned_hub", None) == task_obj.hub:
            return True
            
    if order_obj:
        if order_obj.customer == user or order_obj.driver == user:
            return True
        if order_obj.hub and getattr(user, "assigned_hub", None) == order_obj.hub:
            return True

    if not task_obj and not order_obj and channel_key:
        if channel_key.startswith("delivery_task_"):
            try:
                t_id = int(channel_key.replace("delivery_task_", ""))
                t = DeliveryTask.objects.filter(pk=t_id).first()
                if t and (getattr(t, "target_customer", None) == user or t.driver == user or (t.hub and getattr(user, "assigned_hub", None) == t.hub)):
                    return True
            except Exception:
                pass
        elif channel_key.startswith("delivery_order_"):
            try:
                o_id = channel_key.replace("delivery_order_", "")
                o = LiveOrder.objects.filter(pk=o_id).first()
                if o and (o.customer == user or o.driver == user or (o.hub and getattr(user, "assigned_hub", None) == o.hub)):
                    return True
            except Exception:
                pass

    return False


class DeliveryChatSendView(APIView):
    """
    Send an in-app message between Driver and Customer for a delivery.
    POST /api/deliveries/chat/send/
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        channel_key = request.data.get("channel_key") or request.data.get("channel") or ""
        task_id = request.data.get("task_id")
        order_id = request.data.get("order_id")
        sender_role = request.data.get("sender_role", "DRIVER").upper()  # 'DRIVER' or 'CUSTOMER'
        sender_name = request.data.get("sender_name") or request.user.get_full_name() or request.user.username or "User"
        sender_phone = request.data.get("sender_phone") or getattr(request.user, "phone", "")
        text = request.data.get("text", "").strip()

        if not channel_key and task_id:
            channel_key = f"delivery_task_{task_id}"
        elif not channel_key and order_id:
            channel_key = f"delivery_order_{order_id}"

        if not channel_key or not text:
            return Response(
                {"error": "channel_key and text are required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        task_obj = None
        if task_id:
            try:
                task_obj = DeliveryTask.objects.filter(pk=int(task_id)).first()
            except (ValueError, TypeError):
                pass

        order_obj = None
        if order_id:
            try:
                order_obj = LiveOrder.objects.filter(pk=str(order_id)).first()
            except Exception:
                pass

        if not _is_user_authorized_for_chat(request.user, task_obj=task_obj, order_obj=order_obj, channel_key=channel_key):
            return Response(
                {"detail": "You do not have permission to send messages in this delivery chat."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # 1. Save to PostgreSQL
        msg = DeliveryChatMessage.objects.create(
            channel_key=channel_key,
            task=task_obj,
            order=order_obj,
            sender_role=sender_role,
            sender_name=sender_name,
            sender_phone=sender_phone,
            text=text,
        )

        msg_payload = {
            "id": msg.id,
            "channel_key": msg.channel_key,
            "task_id": task_id,
            "order_id": order_id,
            "sender_role": msg.sender_role,
            "sender_name": msg.sender_name,
            "sender_phone": msg.sender_phone,
            "text": msg.text,
            "is_driver": msg.sender_role == "DRIVER",
            "timestamp": msg.created_at.isoformat(),
        }

        # 2. Trigger In-App Notification for recipient
        try:
            from apps.accounts.models import Notification, User
            recipient_user = None
            if sender_role == "DRIVER":
                # Find customer user
                if task_obj and getattr(task_obj, "target_customer", None):
                    recipient_user = task_obj.target_customer
                elif order_obj and getattr(order_obj, "customer", None):
                    recipient_user = order_obj.customer
                elif sender_phone:
                    # Look up by task customer phone
                    cust_phone = ""
                    if task_obj and hasattr(task_obj, "customer_phone"):
                        cust_phone = task_obj.customer_phone
                    elif order_obj and getattr(order_obj, "customer", None) and order_obj.customer.phone:
                        cust_phone = order_obj.customer.phone
                    if cust_phone:
                        clean_p = cust_phone.replace("+91", "").strip()
                        recipient_user = User.objects.filter(phone__icontains=clean_p).first()

                if recipient_user:
                    Notification.objects.create(
                        user=recipient_user,
                        title=f"💬 {sender_name} (Delivery Partner)",
                        message=text,
                        notification_type="DELIVERY",
                        target_screen="CHAT",
                        target_param=channel_key,
                    )
            elif sender_role == "CUSTOMER":
                # Find driver user
                if task_obj and task_obj.driver:
                    recipient_user = task_obj.driver
                elif order_obj and getattr(order_obj, "driver", None):
                    recipient_user = order_obj.driver
                elif order_obj and getattr(order_obj, "hub", None) and getattr(order_obj.hub, "manager", None):
                    recipient_user = order_obj.hub.manager

                if recipient_user:
                    Notification.objects.create(
                        user=recipient_user,
                        title=f"💬 {sender_name} (Customer)",
                        message=text,
                        notification_type="DELIVERY",
                        target_screen="CHAT",
                        target_param=channel_key,
                    )
        except Exception:
            pass

        # 3. Update Redis Cache Stream
        cache_key = _get_delivery_chat_cache_key(channel_key)
        history = cache.get(cache_key) or []
        history.append(msg_payload)
        if len(history) > 100:
            history = history[-100:]
        cache.set(cache_key, history, timeout=7 * 86400)

        return Response({"status": "success", "message": msg_payload}, status=status.HTTP_201_CREATED)


class DeliveryChatHistoryView(APIView):
    """
    Retrieve real-time conversation history for a delivery channel.
    GET /api/deliveries/chat/history/?channel=...&task_id=...
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        channel_key = request.query_params.get("channel") or request.query_params.get("channel_key") or ""
        task_id = request.query_params.get("task_id")
        order_id = request.query_params.get("order_id")

        task_obj = None
        if task_id:
            try:
                task_obj = DeliveryTask.objects.filter(pk=int(task_id)).first()
            except (ValueError, TypeError):
                pass

        order_obj = None
        if order_id:
            try:
                order_obj = LiveOrder.objects.filter(pk=str(order_id)).first()
            except Exception:
                pass

        if not channel_key and task_id:
            channel_key = f"delivery_task_{task_id}"
        elif not channel_key and order_id:
            channel_key = f"delivery_order_{order_id}"

        if not channel_key:
            return Response(
                {"error": "channel or task_id required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not _is_user_authorized_for_chat(request.user, task_obj=task_obj, order_obj=order_obj, channel_key=channel_key):
            return Response(
                {"detail": "You do not have permission to view this delivery chat."},
                status=status.HTTP_403_FORBIDDEN,
            )

        cache_key = _get_delivery_chat_cache_key(channel_key)
        cached_messages = cache.get(cache_key)

        if cached_messages is not None and len(cached_messages) > 0:
            return Response({"status": "success", "channel_key": channel_key, "messages": cached_messages})

        # Query PostgreSQL
        db_messages = DeliveryChatMessage.objects.filter(channel_key=channel_key).order_by("created_at")
        results = []
        for m in db_messages:
            results.append({
                "id": m.id,
                "channel_key": m.channel_key,
                "task_id": m.task_id,
                "order_id": m.order_id,
                "sender_role": m.sender_role,
                "sender_name": m.sender_name,
                "sender_phone": m.sender_phone,
                "text": m.text,
                "is_driver": m.sender_role == "DRIVER",
                "timestamp": m.created_at.isoformat(),
            })

        cache.set(cache_key, results, timeout=7 * 86400)
        return Response({"status": "success", "channel_key": channel_key, "messages": results})
