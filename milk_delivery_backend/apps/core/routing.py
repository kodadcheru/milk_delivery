from django.urls import re_path
from apps.core import consumers

websocket_urlpatterns = [
    re_path(r"^ws/support/?$", consumers.SupportChatConsumer.as_asgi()),
    re_path(r"^ws/hub/(?P<hub_code>[^/]+)/?$", consumers.HubRealtimeConsumer.as_asgi()),
    re_path(r"^ws/hub/?$", consumers.HubRealtimeConsumer.as_asgi()),
]
