import re
import os

def update_doorstep_camera_dialog():
    filepath = '/Users/galimanideepreddy/Documents/milk_delivery/milk_delivery_frontend/lib/widgets/doorstep_camera_dialog.dart'
    with open(filepath, 'r') as f:
        content = f.read()
    
    target = """                        // If user cancelled camera or on simulator, download preset image bytes as base
                        if (rawBytes == null) {
                          try {
                            final res = await http.get(Uri.parse(activePreset.imageUrl)).timeout(const Duration(seconds: 4));
                            if (res.statusCode == 200) {
                              rawBytes = res.bodyBytes;
                            }
                          } catch (_) {}
                        }"""
    
    replacement = """                        // If user cancelled camera or on simulator, download preset image bytes as base
                        if (rawBytes == null) {
                          if (!mounted) return;
                          setState(() => _isCapturing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: UiTone.error,
                              content: Text('Camera is required for delivery proof. Please try again.'),
                            ),
                          );
                          return;
                        }"""
    
    if target in content:
        content = content.replace(target, replacement)
        with open(filepath, 'w') as f:
            f.write(content)
        print("Updated doorstep_camera_dialog.dart")
    else:
        print("Could not find target in doorstep_camera_dialog.dart")

def update_driver_dashboard_font_sizes():
    filepath = '/Users/galimanideepreddy/Documents/milk_delivery/milk_delivery_frontend/lib/screens/driver/driver_dashboard_screen.dart'
    with open(filepath, 'r') as f:
        content = f.read()

    # Increase font sizes 9, 9.5, 10, 10.5, 11, 11.5 by 1.5
    def replacer(match):
        size = float(match.group(1))
        if 9.0 <= size <= 11.5:
            new_size = size + 1.5
            # keep it as integer if .0
            if new_size.is_integer():
                return f"fontSize: {int(new_size)}"
            else:
                return f"fontSize: {new_size}"
        return match.group(0)

    # First add _locationWarning
    if 'bool _locationWarning = false;' not in content:
        content = content.replace(
            "  double? _lastGoodLng;",
            "  double? _lastGoodLng;\n  bool _locationWarning = false;"
        )
        
    # Update _syncDriverLocation
    sync_target = """    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();"""
    sync_replace = """    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      bool hasPermission = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      if (mounted) {
        setState(() => _locationWarning = !serviceEnabled || !hasPermission);
      }"""
    
    if sync_target in content:
        content = content.replace(sync_target, sync_replace)
    
    # Update build method to include warning banner
    build_target = """    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView("""
    
    build_replace = """    return Column(
      children: [
        if (_locationWarning)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: UiTone.error,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ Location services are off. Hub manager cannot track your location.',
                    style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: UiTone.primary,
            onRefresh: () => widget.state.reloadAllData(),
            child: SingleChildScrollView("""
            
    if build_target in content:
        content = content.replace(build_target, build_replace)
        
    # Find the closing parenthesis of SingleChildScrollView -> actually I wrapped it in Expanded and Column, so I need to add `),` and `],` at the end
    # Actually wait, `return RefreshIndicator(...)` is closed at the very end of the build method.
    # So I need to replace the last `    );` in the build method with `          ), // end Expanded\n        ],\n    );`
    # Let's do it using regex to match the end of build method.
    
    content = re.sub(r'(\s+)child: SingleChildScrollView\(([\s\S]+?)(\n    );\n  }\n}', r'\1child: SingleChildScrollView(\2\n          ),\n        ),\n      ],\n    );\n  }\n}', content)
    
    # Font sizes update
    content = re.sub(r'fontSize:\s*([\d\.]+)', replacer, content)

    with open(filepath, 'w') as f:
        f.write(content)
    print("Updated driver_dashboard_screen.dart")

def update_driver_route_map_screen():
    filepath = '/Users/galimanideepreddy/Documents/milk_delivery/milk_delivery_frontend/lib/screens/driver/driver_route_map_screen.dart'
    with open(filepath, 'r') as f:
        content = f.read()

    if 'bool _locationWarning = false;' not in content:
        content = content.replace(
            "  bool _isLoadingRoadGeometry = false;",
            "  bool _isLoadingRoadGeometry = false;\n  bool _locationWarning = false;"
        )
        
    # Update _startLiveGpsTracking
    sync_target = """      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();"""
    
    sync_replace = """      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      
      bool hasPermission = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      if (mounted) {
        setState(() => _locationWarning = !serviceEnabled || !hasPermission);
      }
      
      if (!serviceEnabled) return;"""
    
    if sync_target in content:
        content = content.replace(sync_target, sync_replace)

    # Update build method for the banner
    build_target = """      body: Stack(
        children: ["""
        
    build_replace = """      body: Column(
        children: [
          if (_locationWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: UiTone.error,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Location services are off. Hub manager cannot track your location.',
                      style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: ["""
              
    if build_target in content:
        content = content.replace(build_target, build_replace)
        # Fix trailing brackets for Stack -> Expanded -> Column
        content = re.sub(r'(\s+)\]\,\n(\s+)\)\,\n    \)\;\n  \}\n\}', r'\1],\n            ),\n          ),\n        ],\n      ),\n    );\n  }\n}', content)

    with open(filepath, 'w') as f:
        f.write(content)
    print("Updated driver_route_map_screen.dart")

def update_day_wise_orders_screen():
    filepath = '/Users/galimanideepreddy/Documents/milk_delivery/milk_delivery_frontend/lib/screens/common/day_wise_orders_screen.dart'
    with open(filepath, 'r') as f:
        content = f.read()

    # Add navigation method
    nav_method = """  void _launchGoogleMapsNavigation(double lat, double lon) async {
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving';
    final uri = Uri.parse(googleMapsUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }
"""
    if '_launchGoogleMapsNavigation' not in content:
        content = content.replace("  void _callPhone(String phone) async {", nav_method + "\n  void _callPhone(String phone) async {")

    # Add navigation icon button
    btn_target = """                IconButton(
                  onPressed: () => _callPhone(phone),"""
    
    btn_replace = """                IconButton(
                  onPressed: () => _launchGoogleMapsNavigation(task.customerLatitude, task.customerLongitude),
                  icon: const Icon(Icons.directions, color: UiTone.accentBlue, size: 20),
                  tooltip: 'Navigate',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(right: 12),
                ),
                IconButton(
                  onPressed: () => _callPhone(phone),"""
                  
    if btn_target in content:
        content = content.replace(btn_target, btn_replace)

    with open(filepath, 'w') as f:
        f.write(content)
    print("Updated day_wise_orders_screen.dart")

if __name__ == '__main__':
    update_doorstep_camera_dialog()
    update_driver_dashboard_font_sizes()
    update_driver_route_map_screen()
    update_day_wise_orders_screen()
