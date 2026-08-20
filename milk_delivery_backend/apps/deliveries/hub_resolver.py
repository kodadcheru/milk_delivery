"""
Utility to resolve the best LocationHub for a customer based on their delivery address.

Resolution strategy (in order of priority):
1. Match delivery pincode against ServiceArea pincodes
2. Find nearest hub by GPS distance (Haversine)
3. Fall back to first available hub
"""
import math
from apps.deliveries.models import LocationHub, ServiceArea


def find_hub_for_location(*, pincode=None, latitude=None, longitude=None, address=None):
    """
    Resolve the best hub for a given delivery location.

    Args:
        pincode: Customer's delivery pincode (e.g., "500033")
        latitude: Customer's delivery latitude
        longitude: Customer's delivery longitude
        address: Customer's address string (used for text matching)

    Returns:
        LocationHub instance or None
    """
    # Strategy 1: Match pincode against active service areas
    if pincode:
        clean_pincode = str(pincode).strip()
        matching_areas = ServiceArea.objects.filter(
            status=ServiceArea.Statuses.ACTIVE,
        ).select_related("hub")

        for area in matching_areas:
            area_pincodes = [p.strip() for p in area.pincodes.split(",")]
            if clean_pincode in area_pincodes and area.hub:
                return area.hub

    # Strategy 2: Match address text against service area names
    if address:
        clean_address = str(address).lower().strip()
        matching_areas = ServiceArea.objects.filter(
            status=ServiceArea.Statuses.ACTIVE,
        ).select_related("hub")

        for area in matching_areas:
            if area.name.lower() in clean_address and area.hub:
                return area.hub

    # Strategy 3: Find nearest hub by GPS (Haversine distance)
    if latitude and longitude:
        try:
            lat = float(latitude)
            lon = float(longitude)
        except (ValueError, TypeError):
            lat, lon = None, None

        if lat and lon:
            hubs = LocationHub.objects.all()
            best_hub = None
            best_distance = float("inf")

            for hub in hubs:
                dist = _haversine_km(lat, lon, hub.latitude, hub.longitude)
                # Only consider hubs within their coverage radius
                if dist <= hub.coverage_radius_km and dist < best_distance:
                    best_distance = dist
                    best_hub = hub

            # If no hub within coverage radius, pick closest within 50km max
            if not best_hub:
                best_distance = float("inf")
                for hub in hubs:
                    dist = _haversine_km(lat, lon, hub.latitude, hub.longitude)
                    if dist < best_distance and dist <= 50.0:
                        best_distance = dist
                        best_hub = hub

            if best_hub:
                return best_hub

    # Strategy 4: Fallback to first hub
    return LocationHub.objects.first()


def _haversine_km(lat1, lon1, lat2, lon2):
    """Calculate great-circle distance between two GPS points in kilometers."""
    R = 6371.0  # Earth radius in km
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c
