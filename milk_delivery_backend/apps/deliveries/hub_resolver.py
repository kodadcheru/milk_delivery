"""
Utility to resolve the best LocationHub for a customer based on their delivery address.

Resolution strategy (in order of priority):
1. Match delivery pincode against ServiceArea pincodes
2. Find nearest hub by GPS distance (Haversine)
3. Fall back to first available hub
"""
import math
import os
from apps.deliveries.models import LocationHub, ServiceArea

MAX_HUB_DISTANCE_KM = float(os.environ.get("MAX_HUB_DISTANCE_KM", "10.0"))


def find_hub_for_location(*, pincode=None, latitude=None, longitude=None, address=None, strict=True):
    """
    Resolve the best hub for a given delivery location.
    If strict=True, returns None when outside all hub coverage areas.
    """
    # Strategy 1: Find nearest hub by GPS (Haversine distance) if coordinates are provided
    if latitude is not None and longitude is not None:
        try:
            lat = float(latitude)
            lon = float(longitude)
            if lat == 0.0 and lon == 0.0:
                lat, lon = None, None
        except (ValueError, TypeError):
            lat, lon = None, None

        if lat is not None and lon is not None:
            hubs = LocationHub.objects.all()
            best_hub = None
            best_distance = float("inf")

            for hub in hubs:
                dist = _haversine_km(lat, lon, hub.latitude, hub.longitude)
                # Only consider hubs within their coverage radius
                if dist <= hub.coverage_radius_km and dist < best_distance:
                    best_distance = dist
                    best_hub = hub

            if best_hub:
                return best_hub

            if strict:
                # If GPS is outside all active hubs' coverage radius in strict mode, reject
                return None

            # If no hub within coverage radius in non-strict mode, pick closest within 10km max
            best_distance = float("inf")
            for hub in hubs:
                dist = _haversine_km(lat, lon, hub.latitude, hub.longitude)
                if dist < best_distance and dist <= MAX_HUB_DISTANCE_KM:
                    best_distance = dist
                    best_hub = hub
            if best_hub:
                return best_hub

    # Strategy 2: Match pincode against active service areas or Hub addresses
    if pincode:
        clean_pincode = str(pincode).strip()
        matching_areas = ServiceArea.objects.filter(
            status=ServiceArea.Statuses.ACTIVE,
        ).select_related("hub")

        for area in matching_areas:
            area_pincodes = [p.strip() for p in area.pincodes.split(",")]
            if clean_pincode in area_pincodes and area.hub:
                return area.hub

        for h in LocationHub.objects.all():
            if clean_pincode in (h.address or ""):
                return h

    # Strategy 3: Match address text against service area names and LocationHub details
    if address:
        clean_address = str(address).lower().strip()
        matching_areas = ServiceArea.objects.filter(
            status=ServiceArea.Statuses.ACTIVE,
        ).select_related("hub")

        for area in matching_areas:
            if area.name.lower() in clean_address and area.hub:
                return area.hub

        # Direct hub name or address matching
        for h in LocationHub.objects.all():
            h_name = (h.name or "").lower()
            h_addr = (h.address or "").lower()
            # TODO: Move these locale tokens to a database table (e.g., ServiceArea.search_keywords) for dynamic management
            key_tokens = ["mella chervu", "mellachervu", "mellacheruvu", "kodad", "suryapet"]
            for token in key_tokens:
                if token in clean_address and (token in h_name or token in h_addr):
                    return h

    # Strategy 4: Fallback to first hub if not strict
    return None if strict else LocationHub.objects.first()


def _haversine_km(lat1, lon1, lat2, lon2):
    """Calculate great-circle distance between two GPS points in kilometers."""
    R = 6371.0  # Earth radius in km
    lat1, lon1, lat2, lon2 = float(lat1), float(lon1), float(lat2), float(lon2)
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c
