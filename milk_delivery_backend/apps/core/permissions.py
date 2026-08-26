from rest_framework import permissions


class IsAdminOrStaff(permissions.BasePermission):
    """Allow access only to admin users or staff members."""
    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and (request.user.is_staff or request.user.is_superuser or getattr(request.user, 'role', '') == 'ADMIN')
        )


class IsAdminOrHubManager(permissions.BasePermission):
    """Allow access to admin users, staff, or hub managers (PROVIDER role)."""
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return False
        role = getattr(request.user, 'role', '')
        return (
            request.user.is_staff
            or request.user.is_superuser
            or role in ('ADMIN', 'PROVIDER', 'HUB_MANAGER')
        )


class IsAdminOrReadOnly(permissions.BasePermission):
    """Allow safe methods (GET, HEAD, OPTIONS) to anyone, but write actions only to admin/staff."""
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        user = getattr(request, "user", None)
        if not (user and user.is_authenticated):
            # Check underlying HttpRequest user for session authentication
            if hasattr(request, "_request") and getattr(request._request, "user", None) and request._request.user.is_authenticated:
                user = request._request.user
        if user and user.is_authenticated:
            return bool(user.is_staff or user.is_superuser or getattr(user, 'role', '') in ('ADMIN', 'PROVIDER', 'HUB_MANAGER'))
        return False
