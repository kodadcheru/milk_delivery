from django.db import migrations


def populate_service_areas(apps, schema_editor):
    LocationHub = apps.get_model("deliveries", "LocationHub")
    ServiceArea = apps.get_model("deliveries", "ServiceArea")

    hub1, _ = LocationHub.objects.get_or_create(
        hub_code="HUB-HYD-01",
        defaults={
            "name": "Jubilee Hills Central Depot #1",
            "address": "Plot 42, Road #36, Jubilee Hills, Hyderabad",
            "latitude": 17.4320,
            "longitude": 78.4070,
            "manager_name": "Rajesh Varma",
            "manager_phone": "+91 98888 77777",
            "fssai_license": "13621014000342",
        }
    )

    hub2, _ = LocationHub.objects.get_or_create(
        hub_code="HUB-HYD-02",
        defaults={
            "name": "Banjara Hills Micro-Depot #2",
            "address": "Road #12, Banjara Hills, Hyderabad",
            "latitude": 17.4156,
            "longitude": 78.4350,
            "manager_name": "Kavitha Reddy",
            "manager_phone": "+91 98765 43211",
            "fssai_license": "13621014000889",
        }
    )

    hub3, _ = LocationHub.objects.get_or_create(
        hub_code="HUB-HYD-03",
        defaults={
            "name": "Madhapur Tech Enclave Depot #3",
            "address": "Hitec City Main Road, Madhapur, Hyderabad",
            "latitude": 17.4483,
            "longitude": 78.3915,
            "manager_name": "Sanjay Rao",
            "manager_phone": "+91 97654 32100",
            "fssai_license": "13621014000912",
        }
    )

    areas = [
        {
            "hub": hub1,
            "name": "Jubilee Hills (Sector A, B & C)",
            "city": "Hyderabad",
            "pincodes": "500033, 500096",
            "radius_km": 4.5,
            "latitude": 17.4320,
            "longitude": 78.4070,
            "status": "ACTIVE",
            "active_households": 128,
            "popular_societies": "Jubilee Hills Enclave, Road 36 Villas, Daspalla Hills",
        },
        {
            "hub": hub1,
            "name": "Film Nagar & Prashasan Nagar",
            "city": "Hyderabad",
            "pincodes": "500096",
            "radius_km": 3.8,
            "latitude": 17.4190,
            "longitude": 78.4110,
            "status": "ACTIVE",
            "active_households": 64,
            "popular_societies": "Film Nagar Cultural Society, MLA Colony, Film Nagar Hills",
        },
        {
            "hub": hub2,
            "name": "Banjara Hills (Road 1 to 14)",
            "city": "Hyderabad",
            "pincodes": "500034",
            "radius_km": 5.0,
            "latitude": 17.4156,
            "longitude": 78.4350,
            "status": "ACTIVE",
            "active_households": 94,
            "popular_societies": "Banjara Heights, Road #12 Lux, Green Valley Enclave",
        },
        {
            "hub": hub3,
            "name": "Madhapur & Hitec City Core",
            "city": "Hyderabad",
            "pincodes": "500081",
            "radius_km": 5.5,
            "latitude": 17.4483,
            "longitude": 78.3915,
            "status": "ACTIVE",
            "active_households": 160,
            "popular_societies": "My Home Bhooja, Rainbow Vistas, Jayabheri Silicon County",
        },
        {
            "hub": hub3,
            "name": "Gachibowli Financial District",
            "city": "Hyderabad",
            "pincodes": "500032, 500075",
            "radius_km": 6.0,
            "latitude": 17.4401,
            "longitude": 78.3489,
            "status": "ACTIVE",
            "active_households": 142,
            "popular_societies": "Aparna Sarovar, Golf View Apartments, Golf Edge",
        },
        {
            "hub": hub3,
            "name": "Kondapur & Botanical Garden",
            "city": "Hyderabad",
            "pincodes": "500084",
            "radius_km": 4.0,
            "latitude": 17.4699,
            "longitude": 78.3578,
            "status": "EXPANDING",
            "active_households": 48,
            "popular_societies": "My Home Mangala, Fortune Fields, Raghava Iris",
        },
        {
            "hub": None,
            "name": "Kukatpally Housing Board (KPHB)",
            "city": "Hyderabad",
            "pincodes": "500072",
            "radius_km": 5.0,
            "latitude": 17.4938,
            "longitude": 78.3995,
            "status": "WAITLIST",
            "active_households": 210,
            "popular_societies": "Lodha Bellezza, Malaysian Township, Vertex Pleasant",
        },
    ]

    for a in areas:
        ServiceArea.objects.get_or_create(
            name=a["name"],
            defaults=a,
        )


class Migration(migrations.Migration):
    dependencies = [
        ("deliveries", "0002_locationhub_servicearea"),
    ]

    operations = [
        migrations.RunPython(populate_service_areas),
    ]
