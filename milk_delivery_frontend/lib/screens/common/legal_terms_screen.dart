import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';
import '../customer/help_support_screen.dart';

enum LegalTab { privacy, terms }

class LegalTermsScreen extends StatefulWidget {
  final AppState state;
  final LegalTab initialTab;

  const LegalTermsScreen({
    super.key,
    required this.state,
    this.initialTab = LegalTab.privacy,
  });

  @override
  State<LegalTermsScreen> createState() => _LegalTermsScreenState();
}

class _LegalTermsScreenState extends State<LegalTermsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _privacyFilter = 'ALL';
  String _termsFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == LegalTab.privacy ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchEmail(String email, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': subject},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isTe = widget.state.isTelugu;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTe ? 'చట్టపరమైన పత్రాలు & నిబంధనలు' : 'Legal & Policies',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const Text(
              'Pamba Dairy Technologies Pvt. Ltd.',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF0D7C66),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              onTap: (_) => HapticFeedback.selectionClick(),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(isTe ? 'గోప్యతా విధానం' : 'Privacy Policy'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.gavel_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(isTe ? 'నిబంధనలు & షరతులు' : 'Terms of Service'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrivacyTab(context, isTe),
          _buildTermsTab(context, isTe),
        ],
      ),
      bottomNavigationBar: _buildStickyFooter(context, isTe),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 1. PRIVACY POLICY TAB ─────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPrivacyTab(BuildContext context, bool isTe) {
    final sections = [
      _LegalSection(
        id: 'collection',
        category: 'DATA',
        number: '01',
        icon: Icons.person_search_rounded,
        accentColor: const Color(0xFF0D7C66),
        title: isTe ? '1. మేము సేకరించే సమాచారం' : '1. Information We Collect',
        tag: isTe ? 'కనీస డేటా' : 'Minimal Data',
        summary: isTe
            ? 'తాజా పాలను మీ ఇంటి గుమ్మానికి చేర్చడానికి అవసరమైన కనీస సమాచారాన్ని మాత్రమే సేకరిస్తాము.'
            : 'We collect only the essential personal details required to deliver farm fresh milk to your doorstep.',
        bullets: [
          isTe
              ? 'వ్యక్తిగత వివరాలు: మీ పేరు, ధృవీకరించబడిన మొబైల్ ఫోన్ నంబర్ మరియు ప్రాథమిక ప్రొఫైల్ వివరాలు.'
              : 'Identity Information: Full Name, verified mobile phone number, and optional email address for delivery invoices.',
          isTe
              ? 'ఖచ్చితమైన డెలివరీ చిరునామా: ఫ్లాట్/ఇంటి సంఖ్య, అపార్ట్‌మెంట్ పేరు, ల్యాండ్‌మార్క్ మరియు ఖచ్చితమైన పిన్‌పాయింట్ GPS కోఆర్డినేట్‌లు.'
              : 'Doorstep Delivery Location: Flat/Door number, society/apartment name, street landmark, and precise GPS pinpoint coordinates to guide morning drivers.',
          isTe
              ? 'పరికర సమాచారం: తెల్లవారుజామున ఆర్డర్ నోటిఫికేషన్‌లు మరియు డెలివరీ స్థితి హెచ్చరికల కోసం FCM పుష్ నోటిఫికేషన్ టోకెన్.'
              : 'Device & Push Tokens: Device identifier, operating system version, and Firebase Cloud Messaging (FCM) tokens solely to send dawn delivery arrival alerts.',
          isTe
              ? 'డోర్‌స్టెప్ ఫోటో ప్రూఫ్: డెలివరీ భాగస్వామి మీ పాల ప్యాకెట్ గుమ్మం వద్ద ఉంచినట్లు తీసిన ఫోటో (వివాదాల పరిష్కారానికి మాత్రమే).'
              : 'Doorstep Delivery Proof: Photographic evidence captured by our delivery drivers showing package placement at your doorstep to resolve claims.',
        ],
      ),
      _LegalSection(
        id: 'usage',
        category: 'USAGE',
        number: '02',
        icon: Icons.local_shipping_rounded,
        accentColor: const Color(0xFF2563EB),
        title: isTe ? '2. మీ సమాచారాన్ని ఎలా ఉపయోగిస్తాము' : '2. How We Use Your Information',
        tag: isTe ? 'డెలివరీ సేవలు' : 'Operational Delivery',
        summary: isTe
            ? 'మీ సమాచారం మీ ఆర్డర్‌లను పూర్తి చేయడానికి మరియు అత్యుత్తమ సేవను అందించడానికి మాత్రమే ఉపయోగించబడుతుంది.'
            : 'Your information is used strictly to fulfill subscriptions, plan morning driver routes, and manage seamless doorstep drops.',
        bullets: [
          isTe
              ? 'ప్రతిరోజూ ఉదయం 05:30 నుండి 07:30 గంటల మధ్య మీ తాజా పాల ఆర్డర్‌లను సురక్షితంగా డెలివరీ చేయడానికి.'
              : 'Dispatching and fulfilling recurring morning subscriptions and express dairy deliveries between 5:30 AM and 7:30 AM.',
          isTe
              ? 'మీ డెలివరీ డ్రైవర్‌కు అత్యంత వేగవంతమైన మరియు ఖచ్చితమైన మార్గాన్ని మ్యాప్ చేయడానికి.'
              : 'Calculating optimal delivery batches and routing our verified depot delivery partners directly to your doorstep.',
          isTe
              ? 'లైవ్ ఆర్డర్ స్టేటస్ అప్‌డేట్‌లు, బయలుదేరిన సమయం మరియు డోర్‌స్టెప్ డ్రాప్ నిర్ధారణలను పంపడానికి.'
              : 'Dispatching real-time notifications when the milk vehicle departs the depot and when items are dropped at your door.',
          isTe
              ? 'పారదర్శకమైన వాలెట్ డిడక్షన్లు, క్యాష్ ఆన్ డెలివరీ రశీదులు మరియు రీఛార్జ్ ఇన్‌వాయిస్‌లను నిర్వహించడానికి.'
              : 'Processing automated wallet auto-debits, generating transparent daily digital receipts, and managing doorstep COD/UPI payments.',
        ],
      ),
      _LegalSection(
        id: 'location',
        category: 'GPS',
        number: '03',
        icon: Icons.location_on_rounded,
        accentColor: const Color(0xFF059669),
        title: isTe ? '3. లొకేషన్ & GPS సేవలు' : '3. Location & GPS Tracking Policy',
        tag: isTe ? 'బ్యాక్‌గ్రౌండ్ ట్రాకింగ్ లేదు' : 'No Background Tracking',
        summary: isTe
            ? 'కస్టమర్ల కోసం ఎటువంటి అనవసర బ్యాక్‌గ్రౌండ్ లొకేషన్ ట్రాకింగ్ ఉండదు.'
            : 'We only access customer location while setting up delivery addresses. We NEVER continuously track customer locations in the background.',
        bullets: [
          isTe
              ? 'చిరునామా నమోదు సమయంలో మీ ఖచ్చితమైన డోర్‌స్టెప్ లొకేషన్‌ను మ్యాప్‌లో పిన్ చేయడానికి మాత్రమే లొకేషన్ అనుమతి కోరబడుతుంది.'
              : 'Location permission is used strictly during address setup to pin your delivery coordinates with sub-meter doorstep accuracy.',
          isTe
              ? 'డెలివరీ భాగస్వాములు మీ ఇంటికి 50 మీటర్ల పరిధిలోకి చేరుకున్నప్పుడు గుర్తించడానికి జియోఫెన్సింగ్ ఉపయోగించబడుతుంది.'
              : 'Geofencing checks verify that the assigned driver is physically within 50 meters of your doorstep when marking a task delivered.',
          isTe
              ? 'డ్రైవర్ల కోసం మాత్రమే: ఉదయం షిఫ్ట్ సమయంలో రూట్ ట్రాకింగ్ మరియు హబ్ మేనేజర్ భద్రతా పర్యవేక్షణ కోసం లొకేషన్ యాక్సెస్ చేయబడుతుంది.'
              : 'For Delivery Drivers only: Foreground location is streamed during active morning shifts to optimize navigation and driver safety.',
        ],
      ),
      _LegalSection(
        id: 'no_selling',
        category: 'PRIVACY',
        number: '04',
        icon: Icons.verified_user_rounded,
        accentColor: const Color(0xFF7C3AED),
        title: isTe ? '4. డేటా అమ్మకం లేదు (Zero Data Selling)' : '4. Zero Data-Selling Pledge',
        tag: isTe ? '100% ప్రైవేట్' : 'We Never Sell Data',
        summary: isTe
            ? 'మీ వ్యక్తిగత వివరాలను, ఫోన్ నంబర్‌ను మేము ఎప్పుడూ ఏ మూడవ పక్షానికి విక్రయించము.'
            : 'We firmly pledge that Pamba has never sold, rented, or monetized user phone numbers or delivery records to advertisers, data brokers, or telemarketers.',
        bullets: [
          isTe
              ? 'మీ ఫోన్ నంబర్ స్పామ్ కాల్స్ లేదా మార్కెటింగ్ ఏజెన్సీలకు ఎప్పటికీ షేర్ చేయబడదు.'
              : 'Your personal contact details are completely quarantined from external ad networks and cold-calling agencies.',
          isTe
              ? 'మీకు కేటాయించిన డెలివరీ డ్రైవర్‌కు కేవలం మీ పేరు, డెలివరీ అడ్రస్ మరియు డెలివరీ సూచనలు మాత్రమే కనిపిస్తాయి.'
              : 'Assigned drivers only receive your first name, delivery address, and delivery notes necessary for completing the morning drop.',
          isTe
              ? 'బ్యాంకింగ్ & చెల్లింపు డేటా: UPI మరియు కార్డ్ చెల్లింపులు RBI-ధృవీకరించబడిన సురక్షిత గేట్‌వేల ద్వారా మాత్రమే ప్రాసెస్ చేయబడతాయి; మీ CVV లేదా కార్డ్ నంబర్ మా సర్వర్‌లలో నిల్వ చేయబడవు.'
              : 'Financial details: All payments are processed via RBI-licensed payment gateways. Card numbers, PINs, and CVVs are NEVER stored on our servers.',
        ],
      ),
      _LegalSection(
        id: 'camera',
        category: 'SECURITY',
        number: '05',
        icon: Icons.camera_alt_rounded,
        accentColor: const Color(0xFFEA580C),
        title: isTe ? '5. కెమెరా & డోర్‌స్టెప్ ఫోటో భద్రత' : '5. Camera & Doorstep Proof Security',
        tag: isTe ? 'వివాద పరిష్కారం' : '30-Day Auto Purge',
        summary: isTe
            ? 'డెలివరీ వివాదాలను నివారించడానికి మాత్రమే కెమెరా ఫోటో రుజువు ఉపయోగించబడుతుంది.'
            : 'Doorstep photos confirm silent morning delivery. Photos are strictly stored for 30 days and accessible only to you and depot supervisors.',
        bullets: [
          isTe
              ? 'డోర్‌స్టెప్ ఫోటోలు సురక్షితమైన ప్రైవేట్ క్లౌడ్ స్టోరేజ్‌లో గుప్తీకరించబడి (encrypted) ఉంటాయి.'
              : 'Delivery photos are encrypted and stored in secure private cloud buckets with access restricted to authenticated account owners.',
          isTe
              ? '30 రోజుల తర్వాత పాత డెలివరీ ఫోటోలు ఆటోమేటిక్‌గా సర్వర్‌ల నుండి శాశ్వతంగా తొలగించబడతాయి.'
              : 'Delivery proofs are retained for 30 days for discrepancy reviews, after which they are permanently and automatically purged.',
          isTe
              ? 'మీ అనుమతి లేకుండా ఎలాంటి ఇతర ఫోటోలు లేదా గ్యాలరీ ఫైల్స్ యాక్సెస్ చేయబడవు.'
              : 'The app never accesses your personal photo gallery or camera roll without explicit permission.',
        ],
      ),
      _LegalSection(
        id: 'deletion',
        category: 'RIGHTS',
        number: '06',
        icon: Icons.delete_forever_rounded,
        accentColor: const Color(0xFFDC2626),
        title: isTe ? '6. ఖాతా తొలగింపు & మీ హక్కులు' : '6. Account Deletion & User Rights',
        tag: isTe ? 'Apple 5.1.1 & DPDP' : '1-Tap Permanent Delete',
        summary: isTe
            ? 'మీ ఖాతాను మరియు మొత్తం డేటాను ఎప్పుడైనా శాశ్వతంగా తొలగించే పూర్తి హక్కు మీకు ఉంది.'
            : 'You have full autonomy over your personal data under the Digital Personal Data Protection Act (DPDP) and Apple Store Guidelines.',
        bullets: [
          isTe
              ? 'ప్రొఫైల్ ట్యాబ్‌లోని "Delete Account" బటన్ ద్వారా మీ ఖాతాను 1-ట్యాప్‌తో శాశ్వతంగా తొలగించవచ్చు.'
              : 'You can initiate complete, irreversible account deletion directly inside Profile → "Delete Account" at any time without emailing support.',
          isTe
              ? 'ఖాతా తొలగించిన వెంటనే మీ చిరునామాలు, ఆర్డర్ చరిత్ర మరియు వ్యక్తిగత రికార్డులు మా డేటాబేస్ నుండి పూర్తిగా తుడిచివేయబడతాయి.'
              : 'Upon confirmation, all active subscriptions are terminated, and your addresses, device tokens, and identity records are permanently deleted.',
          isTe
              ? 'మీ డేటా కాపీని అభ్యర్థించడానికి grievance@pambamilk.com కు ఈమెయిల్ చేయవచ్చు.'
              : 'You have the right to request an export of your transaction history by contacting our grievance officer.',
        ],
      ),
      _LegalSection(
        id: 'grievance',
        category: 'CONTACT',
        number: '07',
        icon: Icons.support_agent_rounded,
        accentColor: const Color(0xFF0F766E),
        title: isTe ? '7. ఫిర్యాదుల అధికారి & సంప్రదింపు వివరాలు' : '7. Grievance Officer & Official Contact',
        tag: isTe ? 'చట్టపరమైన మద్దతు' : 'Official Redressal',
        summary: isTe
            ? 'ఏవైనా గోప్యతా సమస్యలు లేదా ప్రశ్నల కోసం మా అధికారిక ఫిర్యాదుల విభాగాన్ని సంప్రదించండి.'
            : 'In compliance with Information Technology (Intermediary Guidelines) Rules, 2021 and DPDP Act 2023, our grievance officer details are provided below.',
        bullets: [
          'Grievance Officer: Pamba Legal & Compliance Cell',
          'Company: Pamba Dairy Technologies Private Limited',
          'Corporate Address: Plot 42, Jubilee Enclave, Madhapur, Hyderabad, Telangana - 500081, India',
          'Direct Legal Email: grievance@pambamilk.com',
          'Customer Support Desk: support@pambamilk.com | +91 91234 56789',
          'Response Time: All privacy or data inquiries will be officially resolved within 48 business hours.',
        ],
      ),
    ];

    final filtered = _privacyFilter == 'ALL'
        ? sections
        : sections.where((s) => s.category == _privacyFilter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        _buildHeroBanner(
          icon: Icons.verified_user_outlined,
          badgeColor: const Color(0xFFDCFCE7),
          badgeTextColor: const Color(0xFF0D7C66),
          badgeText: isTe ? 'ధృవీకరించబడిన డేటా రక్షణ • DPDP Act 2023' : 'Certified Data Protection • DPDP Act 2023',
          title: isTe ? 'పాంబ గోప్యతా విధానం' : 'Pamba Privacy Policy',
          subtitle: isTe
              ? 'చివరిగా నవీకరించబడింది: సెప్టెంబర్ 1, 2026 • వెర్షన్ 2.4\nమీ వ్యక్తిగత సమాచారాన్ని మేము ఎలా గౌరవిస్తాము మరియు రక్షిస్తాము అనేది ఇక్కడ స్పష్టంగా వివరించబడింది.'
              : 'Last Updated: September 1, 2026 • Version 2.4\nYour trust is our cornerstone. Here is exactly how we safeguard your personal information and delivery coordinates.',
        ),
        const SizedBox(height: 12),

        // Quick Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', isTe ? 'అన్నీ' : 'All Sections', _privacyFilter == 'ALL', () {
                setState(() => _privacyFilter = 'ALL');
              }),
              _buildFilterChip('DATA', isTe ? 'సేకరించిన డేటా' : 'Collected Data', _privacyFilter == 'DATA', () {
                setState(() => _privacyFilter = 'DATA');
              }),
              _buildFilterChip('GPS', isTe ? 'లొకేషన్' : 'GPS & Maps', _privacyFilter == 'GPS', () {
                setState(() => _privacyFilter = 'GPS');
              }),
              _buildFilterChip('PRIVACY', isTe ? 'అమ్మకం లేదు' : 'No Data Selling', _privacyFilter == 'PRIVACY', () {
                setState(() => _privacyFilter = 'PRIVACY');
              }),
              _buildFilterChip('RIGHTS', isTe ? 'ఖాతా హక్కులు' : 'User Rights', _privacyFilter == 'RIGHTS', () {
                setState(() => _privacyFilter = 'RIGHTS');
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section Cards
        ...filtered.map((s) => _buildSectionCard(s)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── 2. TERMS & CONDITIONS TAB ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTermsTab(BuildContext context, bool isTe) {
    final sections = [
      _LegalSection(
        id: 'acceptance',
        category: 'RULES',
        number: '01',
        icon: Icons.verified_rounded,
        accentColor: const Color(0xFF0D7C66),
        title: isTe ? '1. నిబంధనల అంగీకారం & అర్హత' : '1. Acceptance of Terms & Eligibility',
        tag: isTe ? 'చట్టబద్ధమైన ఒప్పందం' : 'Binding Agreement',
        summary: isTe
            ? 'పాంబ యాప్‌ను ఉపయోగించడం ద్వారా, మీరు ఈ సేవా నిబంధనలకు కట్టుబడి ఉండటానికి అంగీకరిస్తున్నారు.'
            : 'By creating an account, browsing products, or subscribing to deliveries, you agree to be legally bound by these Terms of Service.',
        bullets: [
          isTe
              ? 'ఈ ఒప్పందం కస్టమర్‌గా మీకు మరియు Pamba Dairy Technologies Pvt. Ltd. మధ్య వర్తిస్తుంది.'
              : 'These terms constitute a legally binding electronic contract between you (the Customer) and Pamba Dairy Technologies Pvt. Ltd.',
          isTe
              ? 'సేవలను ఉపయోగించడానికి మీకు కనీసం 18 సంవత్సరాల వయస్సు ఉండాలి లేదా సంరక్షకుల పర్యవేక్షణలో ఉండాలి.'
              : 'Users must be at least 18 years of age or possess legal parental/guardian consent to enter into financial subscriptions.',
          isTe
              ? 'మీ మొబైల్ నంబర్ మరియు డెలివరీ చిరునామా ఎల్లప్పుడూ ఖచ్చితమైనవిగా మరియు క్రియాశీలంగా ఉండాలి.'
              : 'You agree to provide accurate, current, and verifiable mobile phone credentials and doorstep delivery directions.',
        ],
      ),
      _LegalSection(
        id: 'subscriptions',
        category: 'DELIVERY',
        number: '02',
        icon: Icons.alarm_on_rounded,
        accentColor: const Color(0xFF2563EB),
        title: isTe ? '2. రోజువారీ సబ్‌స్క్రిప్షన్‌లు & డెలివరీ సమయాలు' : '2. Subscriptions & Dawn Delivery Timings',
        tag: isTe ? 'తెల్లవారుజామున 05:30 - 07:30' : '5:30 AM - 7:30 AM Drop',
        summary: isTe
            ? 'రోజువారీ తాజా పాలు తెల్లవారుజామున నిశ్శబ్దంగా మీ డోర్‌స్టెప్ బుట్టలో ఉంచబడతాయి.'
            : 'All daily recurring milk subscriptions are guaranteed to reach your designated doorstep basket between 5:30 AM and 7:30 AM every morning.',
        bullets: [
          isTe
              ? 'నిశ్శబ్ద డెలివరీ: తెల్లవారుజామున నిద్రకు భంగం కలగకుండా డ్రైవర్లు డోర్‌బెల్ మోగించరు (మీరు ప్రత్యేకంగా అభ్యర్థిస్తే తప్ప).'
              : 'Silent Drop Guarantee: To protect your morning peace, our delivery drivers will never ring doorbells unless explicitly configured in your profile preferences.',
          isTe
              ? 'డెలివరీ కట్-ఆఫ్ సమయం: మరుసటి రోజు ఆర్డర్ మార్పులు, పరిమాణ సర్దుబాటు లేదా సెలవు పాజ్‌లు రాత్రి 10:00 గంటలకు ముందు చేయాలి.'
              : 'Daily Cut-off Window: Any modifications, extra milk requests, or vacation pauses for next-day delivery must be submitted prior to the 10:00 PM evening cut-off.',
          isTe
              ? 'రాత్రి 10:00 గంటల తర్వాత చేసిన మార్పులు మరుసటి రోజు కాకుండా ఆ పై రోజు నుండి మాత్రమే అమలులోకి వస్తాయి.'
              : 'Modifications submitted after 10:00 PM will take effect on the second following morning due to overnight dairy procurement batches.',
        ],
      ),
      _LegalSection(
        id: 'wallet',
        category: 'PAYMENT',
        number: '03',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: const Color(0xFF059669),
        title: isTe ? '3. ధరలు, పాంబ వాలెట్ & క్యాష్ ఆన్ డెలివరీ' : '3. Pricing, Pamba Wallet & Payments',
        tag: isTe ? 'డెలివరీ తర్వాతే ఛార్జ్' : 'Post-Delivery Debit',
        summary: isTe
            ? 'మీ వాలెట్ నుండి డబ్బు డెలివరీ విజయవంతంగా పూర్తయిన తర్వాత మాత్రమే తగ్గించబడుతుంది.'
            : 'Wallet balances are auto-debited only after successful doorstep delivery proof is verified. You are never billed for undelivered goods.',
        bullets: [
          isTe
              ? 'ధరలు: అన్ని ధరలు MRP మరియు వర్తించే పన్నులతో (GST) కూడి ఉంటాయి. అదనపు హిడెన్ ఛార్జీలు లేవు.'
              : 'Transparent Pricing: Product rates are inclusive of all applicable taxes. Any packaging fee waivers are clearly reflected on your itemized checkout bill.',
          isTe
              ? 'పాంబ వాలెట్ ఆటో-డెబిట్: తెల్లవారుజామున డ్రైవర్ డెలివరీ మార్క్ చేసిన తర్వాతే వాలెట్ నుండి సంబంధిత మొత్తం డెబిట్ చేయబడుతుంది.'
              : 'Fair Auto-Debit: For active daily subscriptions, wallet debits occur strictly after doorstep drop confirmation, not days in advance.',
          isTe
              ? 'క్యాష్ ఆన్ డెలివరీ (COD) & UPI: డోర్‌స్టెప్ వద్ద నగదు లేదా GPay / PhonePe / Paytm QR కోడ్ స్కాన్ చేసి చెల్లించవచ్చు.'
              : 'Cash & Doorstep UPI: If COD is selected, customers can pay via cash or scan the delivery partner’s authenticated dynamic UPI QR code.',
          isTe
              ? 'రీఫండబుల్ నిల్వ: మీరు సేవలను నిలిపివేసినప్పుడు ఉపయోగించని వాలెట్ నిల్వను పూర్తిగా మీ అసలు బ్యాంక్ ఖాతాకు రీఫండ్ పొందవచ్చు.'
              : 'Refundable Wallet: Any unutilized deposited wallet balance is 100% refundable upon account closure or cancellation request.',
        ],
      ),
      _LegalSection(
        id: 'proof',
        category: 'DELIVERY',
        number: '04',
        icon: Icons.camera_alt_rounded,
        accentColor: const Color(0xFFEA580C),
        title: isTe ? '4. డోర్‌స్టెప్ ప్రూఫ్ & సంరక్షణ బాధ్యత' : '4. Unattended Drop & Photographic Proof',
        tag: isTe ? 'నిర్ధారణ ఫోటో' : 'Photo Verified',
        summary: isTe
            ? 'ఉదయాన్నే అందజేసే ఉత్పత్తులను సురక్షితమైన పాల బ్యాగ్‌లో ఉంచడం మరియు తక్షణమే తీసుకోవడం కస్టమర్ బాధ్యత.'
            : 'Fresh dairy is perishable. Customers are requested to hang clean doorstep milk pouches or collect drops promptly in the morning.',
        bullets: [
          isTe
              ? 'డ్రైవర్ డెలివరీని పూర్తి చేసినట్లుగా డోర్‌స్టెప్ వద్ద ఉన్న ప్యాకెట్ ఫోటోను రికార్డు చేస్తారు.'
              : 'Delivery Confirmation: Drivers capture timestamped doorstep photos of the placed milk packet as proof of delivery.',
          isTe
              ? 'ఫోటో ప్రూఫ్ మరియు డెలివరీ నోటిఫికేషన్ అందిన తర్వాత, పాలను వీలైనంత త్వరగా ఫ్రిజ్‌లో భద్రపరచుకోవడం కస్టమర్ బాధ్యత.'
              : 'Perishable Care: Because cow & buffalo milk is 100% natural with zero artificial preservatives, products should be refrigerated promptly after drop.',
          isTe
              ? 'డోర్‌స్టెప్ బుట్ట లేదా బ్యాగ్ ఏర్పాటు చేయడం వల్ల వేడి, పెంపుడు జంతువుల నుండి పాలు సురక్షితంగా ఉంటాయి.'
              : 'We strongly recommend installing an insulated doorstep delivery bag to shield dairy packets from ambient morning heat or stray animals.',
        ],
      ),
      _LegalSection(
        id: 'refunds',
        category: 'REFUNDS',
        number: '05',
        icon: Icons.replay_circle_filled_rounded,
        accentColor: const Color(0xFFDC2626),
        title: isTe ? '5. నాణ్యత హామీ, నష్టం & రీఫండ్ విధానం' : '5. 100% Quality Guarantee & Refund Policy',
        tag: isTe ? '4-గంటల విండో' : '4-Hour Resolution Window',
        summary: isTe
            ? 'పాలు చెడిపోయినా లేదా డ్యామేజ్ అయినా 4 గంటల్లోగా తెలియజేస్తే తక్షణ రీఫండ్ లేదా రీప్లేస్‌మెంట్ లభిస్తుంది.'
            : 'If milk is soured, curdled upon boiling, leaked, or missing, report within 4 hours for an unconditional instant refund or replacement.',
        bullets: [
          isTe
              ? 'నాణ్యత హామీ: మా పాలు 100% స్వచ్ఛమైనవి, యాంటీబయాటిక్స్ మరియు కృత్రిమ రసాయనాలు లేనివి.'
              : 'Purity Guarantee: Pamba milk undergoes rigorous 24-parameter laboratory testing for purity, aflatoxins, and water adulteration.',
          isTe
              ? 'ఫిర్యాదు దాఖలు: ప్యాకెట్ డ్యామేజ్ లేదా సమస్య ఉంటే డెలివరీ అయిన 4 గంటల్లోగా యాప్‌లోని సపోర్ట్ చాట్ లేదా హెల్ప్‌లైన్ ద్వారా ఫోటోతో నివేదించాలి.'
              : 'Reporting Discrepancies: In case of curdling upon first boil or package leakage, report within 4 hours of morning delivery with a photo.',
          isTe
              ? 'తక్షణ రీఫండ్: ధృవీకరించబడిన ఫిర్యాదులకు సంబంధించిన మొత్తం మీ పాంబ వాలెట్‌కు తక్షణమే క్రెడిట్ చేయబడుతుంది.'
              : 'Immediate Credit: Approved refund claims are credited directly to your Pamba in-app wallet within 15 minutes of verification.',
        ],
      ),
      _LegalSection(
        id: 'vacation',
        category: 'RULES',
        number: '06',
        icon: Icons.beach_access_rounded,
        accentColor: const Color(0xFF7C3AED),
        title: isTe ? '6. సెలవు పాజ్ & సబ్‌స్క్రిప్షన్ రద్దు' : '6. Vacation Holds & Cancellation Freedom',
        tag: isTe ? 'ఎప్పుడైనా రద్దు' : 'No Lock-in Period',
        summary: isTe
            ? 'ఎటువంటి జరిమానా లేకుండా ఎన్ని రోజులైనా డెలివరీలను పాజ్ చేసుకోవచ్చు లేదా రద్దు చేసుకోవచ్చు.'
            : 'Zero lock-in contracts. Enjoy complete freedom to pause for travel or cancel subscriptions at any moment without penalty.',
        bullets: [
          isTe
              ? 'సెలవు పాజ్: మీరు ఊరికి వెళ్లేటప్పుడు తేదీల శ్రేణిని (date range) ఎంచుకుని ఉచితంగా డెలివరీలను తాత్కాలికంగా ఆపవచ్చు.'
              : 'Flexible Vacation Mode: Pause deliveries for any continuous date range using the in-app calendar. No wallet deductions occur while paused.',
          isTe
              ? 'లాక్-ఇన్ లేదు: మీరు ఎప్పుడైనా మీ సబ్‌స్క్రిప్షన్‌ను నిలిపివేయవచ్చు; మిగిలిన నిల్వ ఎప్పటికీ రద్దు చేయబడదు.'
              : 'Zero Penalties: Unlike traditional milk vendors, you are never locked into monthly minimums and can cancel subscriptions anytime.',
        ],
      ),
      _LegalSection(
        id: 'jurisdiction',
        category: 'LEGAL',
        number: '07',
        icon: Icons.account_balance_rounded,
        accentColor: const Color(0xFF334155),
        title: isTe ? '7. చట్టపరమైన అధికార పరిధి & పరిమితులు' : '7. Limitation of Liability & Jurisdiction',
        tag: isTe ? 'హైదరాబాద్ కోర్టులు' : 'Hyderabad Jurisdiction',
        summary: isTe
            ? 'ఈ నిబంధనలు భారతీయ చట్టాల ద్వారా నిర్వహించబడతాయి మరియు హైదరాబాద్ అధికార పరిధికి లోబడి ఉంటాయి.'
            : 'These terms are governed by the laws of India. Any disputes are subject to the exclusive jurisdiction of the courts of Hyderabad, Telangana.',
        bullets: [
          isTe
              ? 'ప్రకృతి వైపరీత్యాలు, తీవ్రమైన వర్షాలు లేదా రోడ్డు మూసివేత వంటి అనివార్య కారణాల వల్ల డెలివరీ ఆలస్యం కావొచ్చు (అటువంటి సందర్భాల్లో సమాచారం అందించబడుతుంది).'
              : 'Force Majeure: Pamba is not liable for dawn delivery delays caused by extreme weather, flooding, strikes, or road closures beyond reasonable control.',
          isTe
              ? 'సమస్యలు లేదా చట్టపరమైన సందేహాల కోసం మా న్యాయ విభాగాన్ని legal@pambamilk.com ద్వారా సంప్రదించండి.'
              : 'For formal legal notices, write to legal@pambamilk.com or deliver to our registered office in Madhapur, Hyderabad.',
        ],
      ),
    ];

    final filtered = _termsFilter == 'ALL'
        ? sections
        : sections.where((s) => s.category == _termsFilter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        _buildHeroBanner(
          icon: Icons.gavel_outlined,
          badgeColor: const Color(0xFFFEF3C7),
          badgeTextColor: const Color(0xFFB45309),
          badgeText: isTe ? 'పారదర్శక సేవా నిబంధనలు • భారతదేశ చట్టాలకు లోబడి' : 'Transparent Terms • Governed by Laws of India',
          title: isTe ? 'పాంబ సేవా నిబంధనలు & షరతులు' : 'Pamba Terms of Service',
          subtitle: isTe
              ? 'చివరిగా నవీకరించబడింది: సెప్టెంబర్ 1, 2026 • అధికారిక ఒప్పందం\nతాజా పాల డెలివరీ, వాలెట్ వినియోగం మరియు రీఫండ్ విధానాల నిబంధనలు.'
              : 'Last Updated: September 1, 2026 • Official Terms\nClear rules governing daily dairy subscriptions, cut-off timings, wallet debits, and doorstep drop policies.',
        ),
        const SizedBox(height: 12),

        // Quick Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', isTe ? 'అన్నీ' : 'All Clauses', _termsFilter == 'ALL', () {
                setState(() => _termsFilter = 'ALL');
              }),
              _buildFilterChip('DELIVERY', isTe ? 'డెలివరీ సమయాలు' : 'Delivery & Drop', _termsFilter == 'DELIVERY', () {
                setState(() => _termsFilter = 'DELIVERY');
              }),
              _buildFilterChip('PAYMENT', isTe ? 'చెల్లింపులు & వాలెట్' : 'Wallet & COD', _termsFilter == 'PAYMENT', () {
                setState(() => _termsFilter = 'PAYMENT');
              }),
              _buildFilterChip('REFUNDS', isTe ? 'రీఫండ్ విధానం' : 'Refunds & Spoilage', _termsFilter == 'REFUNDS', () {
                setState(() => _termsFilter = 'REFUNDS');
              }),
              _buildFilterChip('RULES', isTe ? 'సెలవు & రద్దు' : 'Vacation & Rules', _termsFilter == 'RULES', () {
                setState(() => _termsFilter = 'RULES');
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section Cards
        ...filtered.map((s) => _buildSectionCard(s)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── REUSABLE UI BUILDERS ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroBanner({
    required IconData icon,
    required Color badgeColor,
    required Color badgeTextColor,
    required String badgeText,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F5F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0D7C66), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: badgeTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D7C66) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(_LegalSection s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: s.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, color: s.accentColor, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: s.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.tag,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: s.accentColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              s.summary,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
            ),
          ),
          children: [
            const Divider(height: 16, color: Color(0xFFF1F5F9)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: s.bullets.map((bullet) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: s.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bullet,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context, bool isTe) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTe ? 'ప్రశ్నలు లేదా ఫిర్యాదులు ఉన్నాయా?' : 'Questions about policies?',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const Text(
                    'grievance@pambamilk.com',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0D7C66), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _launchEmail('grievance@pambamilk.com', 'Legal/Privacy Query - Pamba Milk App'),
              icon: const Icon(Icons.mail_outline_rounded, size: 16),
              label: Text(isTe ? 'ఈమెయిల్' : 'Email Legal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: isTe ? 'సహాయం & మద్దతు' : 'Help Desk',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HelpSupportScreen(state: widget.state)),
                );
              },
              icon: const Icon(Icons.headset_mic_rounded, color: Color(0xFF0D7C66), size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  final String id;
  final String category;
  final String number;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String tag;
  final String summary;
  final List<String> bullets;

  const _LegalSection({
    required this.id,
    required this.category,
    required this.number,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.tag,
    required this.summary,
    required this.bullets,
  });
}
