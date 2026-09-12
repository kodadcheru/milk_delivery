// TODO: Most translations below are not yet wired to UI widgets.
// Wire these using AppLocalizations.of(context) when enabling multi-language support.

class AppTranslations {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Navigation
      'home': 'Home',
      'subscriptions': 'Subscriptions',
      'tracking': 'Live Track',
      'bookings': 'Your Orders',
      'wallet': 'Wallet',
      'profile': 'Profile',

      // Actions & Buttons
      'subscribe_now': 'Subscribe Now',
      'add_to_cart': 'Add to Cart',
      'buy_once': 'Instant Buy',
      'recharge_wallet': 'Recharge Wallet',
      'pay_now': 'Pay Now',
      'confirm_order': 'Confirm Order',
      'proceed_to_pay': 'Proceed to Pay',
      'manage_subscription': 'Manage Subscription',
      'pause_subscription': 'Pause Subscription',
      'resume_subscription': 'Resume Subscription',
      'cancel_subscription': 'Cancel Subscription',
      'save_address': 'Save Address',
      'deliver_here': 'Deliver Here',
      'change_location': 'Change Location',
      'view_details': 'View Details',
      'view_invoice': 'View Invoice',
      'rate_delivery': 'Rate Delivery',
      'live_chat': 'Live Chat',
      'call_support': 'Call Support',
      'start_deliveries': 'Start Deliveries',
      'mark_delivered': 'Mark Delivered',

      // Frequency & Slots
      'daily': 'Daily (Everyday)',
      'alternate_days': 'Alternate Days',
      'every_3_days': 'Every 3 Days',
      'custom_days': 'Custom Days',
      'morning_slot': 'Morning (05:30 AM - 07:00 AM)',
      'evening_slot': 'Evening (06:00 PM - 08:00 PM)',
      'morning_shift': 'Morning Delivery Shift',
      'evening_shift': 'Evening Delivery Shift',

      // Statuses & Badges
      'delivered': 'Delivered',
      'pending': 'Pending',
      'on_the_way': 'On the Way',
      'active': 'Active',
      'paused': 'Paused',
      'cancelled': 'Cancelled',
      'completed': 'Completed',
      'bestseller': 'Bestseller',
      'fresh_today': 'Fresh Today',
      'certified_quality': '100% Certified Lab Quality',

      // Headers & Sections
      'delivery_location': 'DELIVERY LOCATION',
      'daily_subscription_plans': 'Daily Subscription Plans',
      'explore_categories': 'Explore Categories',
      'recent_orders': 'Recent Orders',
      'wallet_balance': 'Wallet Balance',
      'quick_recharge': 'Quick Recharge',
      'delivery_preferences': 'Delivery Preferences',
      'address_book': 'Address Book',
      'help_and_support': 'Help & Support',
      'language': 'Language / భాష',
      'about_us': 'About Us',
      'terms_and_privacy': 'Terms & Privacy Policy',
      'logout': 'Logout',

      // Subscription Builder Flow
      'select_pack_size': 'Select Pack Size',
      'choose_quantity': 'Daily Quantity',
      'delivery_shift': 'Delivery Shift',
      'select_duration': 'Subscription Duration',
      'trial_15_days': '15 Days Trial',
      'monthly_30_days': '30 Days Monthly Plan',
      'saver_60_days': '60 Days Super Saver',
      'delivery_schedule': 'Delivery Schedule',
      'drop_preference': 'Doorstep Preference',
      'ring_bell': 'Ring Doorbell',
      'leave_in_basket': 'Leave in Doorstep Basket',
      'call_on_arrival': 'Call on Arrival',
      'special_instructions': 'Special Delivery Instructions',
      'confirm_subscription': 'Confirm & Start Subscription',
      'step_pack': 'Pack & Quantity',
      'step_schedule': 'Schedule & Shift',
      'step_review': 'Review & Confirm',
      'next_step': 'Next Step',
      'prev_step': 'Previous Step',
      'start_date': 'Start Date',

      // Express Cart & Checkout
      'view_cart': 'View Cart',
      'your_cart': 'Your Cart',
      'items': 'items',
      'arriving_tomorrow': 'Arriving Tomorrow by 06:00 AM',
      'arriving_instant': 'Arriving in ~25 mins',
      'deliver_to': 'DELIVER TO',
      'change': 'Change',
      'select_delivery_location': 'Select Delivery Location',
      'delivery_speed': 'Delivery Speed',
      'next_day_drop': 'Next-Day Drop',
      'instant_express': 'Instant Express',
      'select_time_slot': 'Select Time Slot',
      'frequently_bought_together': 'Frequently Bought Together',
      'delivery_instructions': 'Delivery Instructions',
      'dont_ring_bell': "Don't ring bell",
      'leave_at_door': 'Leave at door',
      'avoid_calling': 'Avoid calling',
      'leave_with_guard': 'Leave with guard',
      'add_more_for_free_delivery': 'Add more for FREE delivery',
      'free_delivery_unlocked': 'Yay! FREE Delivery unlocked!',
      'bill_summary': 'Bill Summary',
      'bill_details': 'Bill Details',
      'item_total': 'Item Total',
      'delivery_charge': 'Delivery Partner Fee',
      'free_delivery': 'FREE Delivery',
      'free': 'FREE',
      'platform_fee': 'Platform Fee',
      'taxes_and_charges': 'Taxes & Charges (GST)',
      'wallet_deduction': 'Wallet Deduction',
      'total_to_pay': 'Total to Pay',
      'to_pay': 'To Pay',
      'you_saved': 'You saved on this order!',
      'cancellation_policy': 'Cancellation & Refund Policy',
      'cancellation_policy_note': 'Orders can be cancelled before dispatch without any cancellation fee.',
      'order_placed_celebration': 'Order Placed! 🎉',
      'order_id_label': 'Order #',
      'track_order': 'Track Order',
      'continue_shopping': 'Continue Shopping',
      'cart_is_empty': 'Your cart is empty',
      'cart_empty_sub': 'Browse our fresh dairy, eggs & groceries',
      'start_shopping': 'Start Shopping',
      'select_payment_method': 'Select Payment Method',
      'online_pay': 'Online Payment (UPI, Cards)',
      'cod': 'Cash on Delivery (COD)',
      'pamba_wallet': 'Pamba Prepaid Wallet',
      'available_balance': 'Available Balance',
      'insufficient_balance': 'Insufficient balance. Top up to proceed.',
      'top_up_wallet': 'Top Up Wallet',
      'items_in_cart': 'Items in Cart',
      'payment_options': 'Payment Method',
      'place_order': 'Place Order',
      'order_success': 'Order Placed Successfully!',

      // Authentication
      'welcome_title': 'Farm Fresh Pure Milk',
      'welcome_subtitle': 'Delivered to your doorstep daily before 7:00 AM',
      'login_heading': 'Enter Mobile Number',
      'login_sub': 'We will send a 4-digit verification code',
      'send_otp': 'Get OTP',
      'verify_otp': 'Verify & Login',
      'enter_otp_sub': 'Enter 4-digit OTP sent to',
      'resend_otp': 'Resend OTP',
      'terms_notice': 'By continuing, you agree to Pamba Terms & Privacy Policy',

      // Address Book
      'add_new_address': 'Add New Address',
      'house_no': 'Flat / House / Building No',
      'street_area': 'Street / Area / Colony',
      'landmark': 'Landmark (Optional)',
      'address_tag': 'Save Address As',
      'tag_home': 'Home',
      'tag_work': 'Work',
      'tag_other': 'Other',
      'select_on_map': 'Pick Location on Map',

      // Driver Workflows
      'todays_manifest': "Today's Delivery Manifest",
      'morning_manifest': 'Morning Shift Manifest',
      'evening_manifest': 'Evening Shift Manifest',
      'enter_delivery_otp': 'Enter Customer Delivery OTP',
      'take_doorstep_photo': 'Snap Doorstep Proof Photo',
      'call_customer': 'Call Customer',
      'collect_cash': 'Collect Cash',
      'cash_collected': 'Cash Collected',
      'all_delivered': 'All Deliveries Completed!',
      
      // Features & Network
      'vacation_mode': 'Vacation Mode',
      'forecast_7_day': '7-Day Forecast',
      'tomorrow_quantity': "Tomorrow's Quantity",
      'offline_saved': 'Delivery saved offline. Will sync when back online.',
      'driver_on_way': 'Driver is on the way!',
      'network_error': 'Network connection error. Please try again.',
    },
    'te': {
      // Navigation
      'home': 'హోమ్',
      'subscriptions': 'సబ్‌స్క్రిప్షన్లు',
      'tracking': 'లైవ్ ట్రాకింగ్',
      'bookings': 'మీ ఆర్డర్లు',
      'wallet': 'వాలెట్',
      'profile': 'ప్రొఫైల్',

      // Actions & Buttons
      'subscribe_now': 'ఇప్పుడే సబ్‌స్క్రైబ్ చేయండి',
      'add_to_cart': 'కార్ట్‌కి జోడించండి',
      'buy_once': 'వెంటనే కొనండి',
      'recharge_wallet': 'వాలెట్ రీఛార్జ్',
      'pay_now': 'చెల్లింపు చేయండి',
      'confirm_order': 'ఆర్డర్ నిర్ధారించండి',
      'proceed_to_pay': 'చెల్లింపుకి వెళ్లండి',
      'manage_subscription': 'సబ్‌స్క్రిప్షన్ నిర్వహించండి',
      'pause_subscription': 'సబ్‌స్క్రిప్షన్ పాజ్ చేయండి',
      'resume_subscription': 'సబ్‌స్క్రిప్షన్ పునఃప్రారంభించండి',
      'cancel_subscription': 'సబ్‌స్క్రిప్షన్ రద్దు చేయండి',
      'save_address': 'చిరునామాను భద్రపరచండి',
      'deliver_here': 'ఇక్కడే డెలివరీ చేయండి',
      'change_location': 'స్థానాన్ని మార్చండి',
      'view_details': 'వివరాలు చూడండి',
      'view_invoice': 'ఇన్‌వాయిస్ చూడండి',
      'rate_delivery': 'రేటింగ్ ఇవ్వండి',
      'live_chat': 'లైవ్ చాట్',
      'call_support': 'సహాయ కేంద్రం కాల్ చేయండి',
      'start_deliveries': 'డెలివరీలు ప్రారంభించండి',
      'mark_delivered': 'డెలివరీ పూర్తయింది',

      // Frequency & Slots
      'daily': 'ప్రతిరోజూ (Daily)',
      'alternate_days': 'రోజు విడిచి రోజు (Alternate Days)',
      'every_3_days': 'ప్రతి 3 రోజులకు ఒకసారి',
      'custom_days': 'మీకు నచ్చిన రోజులు',
      'morning_slot': 'ఉదయం (05:30 AM - 07:00 AM)',
      'evening_slot': 'సాయంత్రం (06:00 PM - 08:00 PM)',
      'morning_shift': 'ఉదయం డెలివరీ బ్యాచ్',
      'evening_shift': 'సాయంత్రం డెలివరీ బ్యాచ్',

      // Statuses & Badges
      'delivered': 'డెలివరీ పూర్తయింది',
      'pending': 'పెండింగ్‌లో ఉంది',
      'on_the_way': 'మార్గంలో ఉంది (On the Way)',
      'active': 'యాక్టివ్',
      'paused': 'పాజ్ చేయబడింది',
      'cancelled': 'రద్దు చేయబడింది',
      'completed': 'పూర్తయింది',
      'bestseller': 'అత్యధికంగా అమ్ముడైనది',
      'fresh_today': 'ఈరోజు తాజా ఉత్పత్తి',
      'certified_quality': '100% ల్యాబ్ ధృవీకరించిన నాణ్యత',

      // Headers & Sections
      'delivery_location': 'డెలివరీ స్థానం',
      'daily_subscription_plans': 'రోజువారీ సబ్‌స్క్రిప్షన్ ప్లాన్‌లు',
      'explore_categories': 'కేటగిరీలు బ్రౌజ్ చేయండి',
      'recent_orders': 'ఇటీవలి ఆర్డర్లు',
      'wallet_balance': 'వాలెట్ నిల్వ',
      'quick_recharge': 'త్వరిత రీఛార్జ్',
      'delivery_preferences': 'డెలివరీ ప్రాధాన్యతలు',
      'address_book': 'చిరునామా పుస్తకం',
      'help_and_support': 'సహాయం & మద్దతు',
      'language': 'భాష / Language',
      'about_us': 'మా గురించి',
      'terms_and_privacy': 'నిబంధనలు & గోప్యతా విధానం',
      'logout': 'లాగ్ అవుట్',

      // Subscription Builder Flow
      'select_pack_size': 'ప్యాక్ పరిమాణాన్ని ఎంచుకోండి',
      'choose_quantity': 'రోజువారీ పరిమాణం',
      'delivery_shift': 'డెలివరీ సమయం (షిఫ్ట్)',
      'select_duration': 'సబ్‌స్క్రిప్షన్ కాలపరిమితి',
      'trial_15_days': '15 రోజుల ట్రయల్',
      'monthly_30_days': '30 రోజుల నెలవారీ ప్లాన్',
      'saver_60_days': '60 రోజుల సూపర్ సేవర్',
      'delivery_schedule': 'డెలివరీ షెడ్యూల్',
      'drop_preference': 'డోర్‌స్టెప్ ప్రాధాన్యత',
      'ring_bell': 'డోర్‌బెల్ మోగించండి',
      'leave_in_basket': 'డోర్‌స్టెప్ బుట్టలో ఉంచండి',
      'call_on_arrival': 'వచ్చినప్పుడు కాల్ చేయండి',
      'special_instructions': 'ప్రత్యేక డెలివరీ సూచనలు',
      'confirm_subscription': 'సబ్‌స్క్రిప్షన్ నిర్ధారించండి',
      'step_pack': 'ప్యాక్ & పరిమాణం',
      'step_schedule': 'షెడ్యూల్ & సమయం',
      'step_review': 'సమీక్ష & నిర్ధారణ',
      'next_step': 'తదుపరి దశ',
      'prev_step': 'మునుపటి దశ',
      'start_date': 'ప్రారంభ తేదీ',

      // Express Cart & Checkout
      'view_cart': 'కార్ట్ చూడండి',
      'your_cart': 'మీ కార్ట్',
      'items': 'వస్తువులు',
      'arriving_tomorrow': 'రేపు ఉదయం 06:00 గంటలకు డెలివరీ',
      'arriving_instant': '~25 నిమిషాల్లో డెలివరీ',
      'deliver_to': 'డెలివరీ చిరునామా',
      'change': 'మార్చండి',
      'select_delivery_location': 'డెలివరీ స్థానాన్ని ఎంచుకోండి',
      'delivery_speed': 'డెలివరీ వేగం',
      'next_day_drop': 'రేపటి ఉదయం డెలివరీ',
      'instant_express': 'ఇన్‌స్టంట్ ఎక్స్‌ప్రెస్',
      'select_time_slot': 'డెలివరీ సమయాన్ని ఎంచుకోండి',
      'frequently_bought_together': 'ఎక్కువగా కొనుగోలు చేసేవి',
      'delivery_instructions': 'డెలివరీ సూచనలు',
      'dont_ring_bell': 'డోర్‌బెల్ మోగించవద్దు',
      'leave_at_door': 'తలుపు వద్ద ఉంచండి',
      'avoid_calling': 'కాల్ చేయవద్దు',
      'leave_with_guard': 'సెక్యూరిటీ గార్డు వద్ద ఉంచండి',
      'add_more_for_free_delivery': 'ఉచిత డెలివరీ కోసం ఇంకో జోడించండి',
      'free_delivery_unlocked': 'అభినందనలు! ఉచిత డెలివరీ లభించింది!',
      'bill_summary': 'బిల్లు వివరాలు',
      'bill_details': 'బిల్లు వివరాలు',
      'item_total': 'వస్తువుల మొత్తం',
      'delivery_charge': 'డెలివరీ పార్టనర్ ఛార్జీ',
      'free_delivery': 'ఉచిత డెలివరీ (FREE)',
      'free': 'ఉచితం',
      'platform_fee': 'ప్లాట్‌ఫామ్ ఫీజు',
      'taxes_and_charges': 'పన్నులు & ఛార్జీలు (GST)',
      'wallet_deduction': 'వాలెట్ తగ్గింపు',
      'total_to_pay': 'చెల్లించాల్సిన మొత్తం',
      'to_pay': 'చెల్లించాల్సిన మొత్తం',
      'you_saved': 'ఈ ఆర్డర్‌పై మీరు ఆదా చేశారు!',
      'cancellation_policy': 'రద్దు & రీఫండ్ విధానం',
      'cancellation_policy_note': 'ఆర్డర్ బయలుదేరే ముందు ఎటువంటి రుసుము లేకుండా రద్దు చేసుకోవచ్చు.',
      'order_placed_celebration': 'ఆర్డర్ విజయవంతంగా నమోదయింది! 🎉',
      'order_id_label': 'ఆర్డర్ సంఖ్య #',
      'track_order': 'ఆర్డర్ ట్రాక్ చేయండి',
      'continue_shopping': 'మరిన్ని కొనండి',
      'cart_is_empty': 'మీ కార్ట్ ఖాళీగా ఉంది',
      'cart_empty_sub': 'తాజా పాలు, గుడ్లు మరియు నిత్యావసరాలను ఎంచుకోండి',
      'start_shopping': 'షాపింగ్ ప్రారంభించండి',
      'select_payment_method': 'చెల్లింపు విధానాన్ని ఎంచుకోండి',
      'online_pay': 'ఆన్‌లైన్ చెల్లింపు (UPI, కార్డులు)',
      'cod': 'క్యాష్ ఆన్ డెలివరీ (COD)',
      'pamba_wallet': 'పాంబ ప్రీపెయిడ్ వాలెట్',
      'available_balance': 'అందుబాటులో ఉన్న నిల్వ',
      'insufficient_balance': 'నిల్వ సరిపోదు. కొనసాగడానికి రీఛార్జ్ చేయండి.',
      'top_up_wallet': 'వాలెట్ రీఛార్జ్ చేయండి',
      'items_in_cart': 'కార్ట్ లోని వస్తువులు',
      'payment_options': 'చెల్లింపు విధానం',
      'place_order': 'ఆర్డర్ ఇవ్వండి',
      'order_success': 'ఆర్డర్ విజయవంతంగా నమోదయింది!',

      // Authentication
      'welcome_title': 'స్వచ్ఛమైన ఫారం పాలు',
      'welcome_subtitle': 'ప్రతిరోజూ ఉదయం 7:00 గంటలలోపు మీ ఇంటి ముంగిటకు',
      'login_heading': 'మొబైల్ నంబర్ నమోదు చేయండి',
      'login_sub': 'మేము 4 అంకెల ధృవీకరణ కోడ్‌ను SMS పంపుతాము',
      'send_otp': 'OTP పొందండి',
      'verify_otp': 'ధృవీకరించి లాగిన్ అవ్వండి',
      'enter_otp_sub': 'ఈ నంబర్‌కు పంపిన 4 అంకెల OTP ని నమోదు చేయండి',
      'resend_otp': 'మళ్లీ OTP పంపండి',
      'terms_notice': 'కొనసాగించడం ద్వారా, మీరు పాంబ నిబంధనలు & గోప్యతా విధానాన్ని అంగీకరిస్తున్నారు',

      // Address Book
      'add_new_address': 'కొత్త చిరునామాను జోడించండి',
      'house_no': 'ఇంటి నంబరు / ఫ్లాట్ / భవనం నంబర్',
      'street_area': 'వీధి / ప్రాంతం / కాలనీ',
      'landmark': 'గుర్తు / ల్యాండ్‌మార్క్ (ఐచ్ఛికం)',
      'address_tag': 'చిరునామా రకం',
      'tag_home': 'ఇల్లు (Home)',
      'tag_work': 'ఆఫీస్ (Work)',
      'tag_other': 'ఇతర (Other)',
      'select_on_map': 'మ్యాప్‌లో స్థానాన్ని ఎంచుకోండి',

      // Driver Workflows
      'todays_manifest': "ఈరోజు డెలివరీల జాబితా",
      'morning_manifest': 'ఉదయం షిఫ్ట్ జాబితా',
      'evening_manifest': 'సాయంత్రం షిఫ్ట్ జాబితా',
      'enter_delivery_otp': 'కస్టమర్ డెలివరీ OTP నమోదు చేయండి',
      'take_doorstep_photo': 'డోర్‌స్టెప్ ఫోటో తీయండి',
      'call_customer': 'కస్టమర్‌కు కాల్ చేయండి',
      'collect_cash': 'నగదు స్వీకరించండి',
      'cash_collected': 'నగదు స్వీకరించబడింది',
      'all_delivered': 'అన్ని డెలివరీలు పూర్తయ్యాయి!',
      
      // Features & Network
      'vacation_mode': 'సెలవు మోడ్',
      'forecast_7_day': '7-రోజుల అంచనా',
      'tomorrow_quantity': 'రేపటి పరిమాణం',
      'offline_saved': 'డెలివరీ ఆఫ్లైన్లో సేవ్ చేయబడింది. ఆన్లైన్లోకి వచ్చినప్పుడు సింక్ అవుతుంది.',
      'driver_on_way': 'డ్రైవర్ దారిలో ఉన్నారు!',
      'network_error': 'నెట్వర్క్ కనెక్షన్ లోపం. దయచేసి మళ్ళీ ప్రయత్నించండి.',
    },
  };

  // Product Name Dictionary (English ➔ Telugu)
  static const Map<String, String> _productTeluguNames = {
    'fresh cow milk': 'స్వచ్ఛమైన ఆవు పాలు',
    'cow milk': 'స్వచ్ఛమైన ఆవు పాలు',
    'pure cow milk': 'స్వచ్ఛమైన ఆవు పాలు',
    'buffalo milk': 'చిక్కటి గేదె పాలు',
    'thick buffalo milk': 'చిక్కటి గేదె పాలు',
    'pure buffalo milk': 'స్వచ్ఛమైన గేదె పాలు',
    'a2 desi cow milk': 'A2 దేశీ ఆవు పాలు',
    'a2 cow milk': 'A2 ఆవు పాలు',
    'pure desi cow ghee': 'స్వచ్ఛమైన దేశీ ఆవు నెయ్యి',
    'desi cow ghee': 'దేశీ ఆవు నెయ్యి',
    'cow ghee': 'ఆవు నెయ్యి',
    'pure buffalo ghee': 'స్వచ్ఛమైన గేదె నెయ్యి',
    'farm fresh paneer': 'తాజా ఫారం పనీర్',
    'fresh paneer': 'తాజా పనీర్',
    'malai paneer': 'మలై పనీర్',
    'thick curd': 'చిక్కటి పెరుగు',
    'farm fresh curd': 'ఫారం తాజా పెరుగు',
    'pure curd': 'స్వచ్ఛమైన పెరుగు',
    'fresh dahi': 'తాజా పెరుగు',
    'dahi': 'పెరుగు',
    'spiced butter milk': 'మసాలా మజ్జిగ',
    'butter milk': 'తాజా మజ్జిగ',
    'buttermilk': 'మజ్జిగ',
    'organic farm eggs': 'సేంద్రీయ నాటు కోడి గుడ్లు',
    'organic eggs': 'సేంద్రీయ గుడ్లు',
    'farm eggs': 'తాజా ఫారం గుడ్లు',
    'white eggs': 'తాజా గుడ్లు',
    'raw cow butter': 'స్వచ్ఛమైన వెన్న',
    'white butter': 'తెల్ల వెన్న',
    'mineral water can (20l)': 'మినరల్ వాటర్ క్యాన్ (20 లీటర్లు)',
    'mineral water 20l': 'మినరల్ వాటర్ 20L',
    'water can 20l': 'వాటర్ క్యాన్ 20 లీటర్లు',
    'bisleri water can': 'మినరల్ వాటర్ క్యాన్ 20L',
  };

  // Product Descriptions Dictionary (English ➔ Telugu)
  static const Map<String, String> _descriptionTelugu = {
    'fresh cow milk': 'రోజువారీ ఉదయం మీ ఇంటి ముంగిటకు వచ్చే 100% సహజమైన, స్వచ్ఛమైన ఆవు పాలు. ఎటువంటి రసాయనాలు కలపని సహజ పోషకాలు.',
    'buffalo milk': 'అధిక వెన్న శాతం మరియు చిక్కదనం కలిగిన సహజ సిద్ధమైన గేదె పాలు. టీ, కాఫీ మరియు పెరుగు తయారీకి అత్యుత్తమం.',
    'pure desi cow ghee': 'సాంప్రదాయ బిలోనా పద్ధతిలో కవ్వంతో చిలికి స్వచ్ఛమైన ఆవు వెన్న నుండి తయారుచేసిన కమ్మని సువాసన గల దేశీ నెయ్యి.',
    'farm fresh paneer': 'ఎటువంటి ప్రిజర్వేటివ్స్ లేకుండా రోజూ తాజాగా తయారుచేయబడిన మృదువైన, పోషక విలువలు నిండిన పనీర్.',
    'thick curd': 'సహజ పాలతో తోడుపెట్టిన చిక్కటి, కమ్మనైన పెరుగు. రోగనిరోధక శక్తిని మరియు జీర్ణక్రియను మెరుగుపరుస్తుంది.',
    'organic farm eggs': 'సహజ వాతావరణంలో పెరిగిన నాటు కోళ్ల నుండి సేకరించిన పోషక సమృద్ధమైన ప్రోటీన్ గుడ్లు.',
    'butter milk': 'జీర్ణక్రియకు ఎంతో మేలు చేసే సహజంగా చిలికిన చల్లని, రుచికరమైన మజ్జిగ.',
    'mineral water can (20l)': 'కఠినమైన 8-దశల ఆర్వో ప్యూరిఫికేషన్ ప్రక్రియతో శుద్ధి చేయబడిన పరిశుభ్రమైన తాగునీరు.',
  };

  // Category Dictionary (English ➔ Telugu)
  static const Map<String, String> _categoryTelugu = {
    'milk': 'పాలు & డైరీ',
    'milk & dairy': 'పాలు & డైరీ ఉత్పత్తులు',
    'curd': 'పెరుగు',
    'curd & ghee': 'పెరుగు & నెయ్యి',
    'ghee': 'స్వచ్ఛమైన నెయ్యి',
    'paneer': 'తాజా పనీర్',
    'eggs': 'తాజా గుడ్లు',
    'farm fresh eggs': 'ఫారం తాజా గుడ్లు',
    'water_can': 'మినరల్ వాటర్',
    'water can': 'మినరల్ వాటర్',
    'daily essentials': 'రోజువారీ నిత్యావసరాలు',
    'bakery': 'బేకరీ ఉత్పత్తులు',
    'meat': 'తాజా మాంసం',
  };

  /// Translates standard UI keys
  static String tr(String key, {String lang = 'en'}) {
    final values = _localizedValues[lang] ?? _localizedValues['en']!;
    return values[key] ?? _localizedValues['en']?[key] ?? key;
  }

  /// Translates product names
  static String translateProduct(String originalName, {String lang = 'en'}) {
    if (lang != 'te') return originalName;
    final lower = originalName.trim().toLowerCase();
    for (final entry in _productTeluguNames.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    return originalName;
  }

  /// Translates product descriptions
  static String translateDescription(String originalName, String originalDesc, {String lang = 'en'}) {
    if (lang != 'te') return originalDesc;
    final lower = originalName.trim().toLowerCase();
    for (final entry in _descriptionTelugu.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return originalDesc;
  }

  /// Translates category names
  static String translateCategory(String categoryName, {String lang = 'en'}) {
    if (lang != 'te') return categoryName;
    final lower = categoryName.trim().toLowerCase();
    return _categoryTelugu[lower] ?? categoryName;
  }
}
