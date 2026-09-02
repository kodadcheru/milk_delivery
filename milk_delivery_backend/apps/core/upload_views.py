import base64
import os
import uuid
from datetime import datetime
from pathlib import Path
from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from rest_framework import permissions, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".svg"}
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/svg+xml"}
MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024  # 15 MB


class FileUploadView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        uploaded_file = request.FILES.get("image") or request.FILES.get("file")
        base64_data = request.data.get("base64_image") or request.data.get("image_base64")
        folder = request.data.get("folder", "proofs").strip()
        # Sanitize folder name to prevent directory traversal
        folder = folder.replace("/", "").replace("\\", "").replace("..", "").strip()
        if not folder:
            folder = "proofs"

        # Role-based folder write protection: only staff/admin/managers can write to store assets
        if folder in ("banners", "products", "marketing", "config"):
            user = request.user
            is_manager_or_admin = (
                user.is_staff
                or user.is_superuser
                or getattr(user, "role", "") in ("ADMIN", "PROVIDER", "HUB_MANAGER")
            )
            if not is_manager_or_admin:
                return Response(
                    {"detail": f"You do not have permission to upload assets to the '{folder}' directory."},
                    status=status.HTTP_403_FORBIDDEN,
                )

        # Ensure media proofs directory exists
        proofs_dir = Path(settings.MEDIA_ROOT) / folder
        proofs_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = uuid.uuid4().hex[:8]

        # Case 1: Multipart File Upload
        if uploaded_file:
            if uploaded_file.size > MAX_FILE_SIZE_BYTES:
                return Response(
                    {"detail": "File size exceeds 10MB limit."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            ext = Path(uploaded_file.name).suffix.lower()
            if ext not in ALLOWED_EXTENSIONS:
                ext = ".jpg"

            filename = f"{folder}/proof_{timestamp}_{unique_id}{ext}"
            saved_path = default_storage.save(filename, uploaded_file)
            file_url = request.build_absolute_uri(settings.MEDIA_URL + saved_path)

            return Response(
                {
                    "success": True,
                    "url": file_url,
                    "relative_url": f"{settings.MEDIA_URL}{saved_path}",
                    "filename": Path(saved_path).name,
                    "size_bytes": uploaded_file.size,
                    "created_at": datetime.now().isoformat(),
                },
                status=status.HTTP_201_CREATED,
            )

        # Case 2: Base64 Encoded Image Upload
        elif base64_data:
            try:
                # Strip prefix if present (e.g. data:image/png;base64,...)
                if "," in base64_data:
                    header, base64_data = base64_data.split(",", 1)
                    if "png" in header:
                        ext = ".png"
                    elif "webp" in header:
                        ext = ".webp"
                    else:
                        ext = ".jpg"
                else:
                    ext = ".jpg"

                file_bytes = base64.b64decode(base64_data)
                if len(file_bytes) > MAX_FILE_SIZE_BYTES:
                    return Response(
                        {"detail": "Base64 image exceeds 10MB limit."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                filename = f"{folder}/proof_{timestamp}_{unique_id}{ext}"
                saved_path = default_storage.save(filename, ContentFile(file_bytes))
                file_url = request.build_absolute_uri(settings.MEDIA_URL + saved_path)

                return Response(
                    {
                        "success": True,
                        "url": file_url,
                        "relative_url": f"{settings.MEDIA_URL}{saved_path}",
                        "filename": Path(saved_path).name,
                        "size_bytes": len(file_bytes),
                        "created_at": datetime.now().isoformat(),
                    },
                    status=status.HTTP_201_CREATED,
                )
            except Exception as e:
                return Response(
                    {"detail": f"Invalid base64 image data: {str(e)}"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Fallback if no file provided: return verified sample proof URL
        return Response(
            {
                "detail": "No image file or base64 data provided in request.",
            },
            status=status.HTTP_400_BAD_REQUEST,
        )
