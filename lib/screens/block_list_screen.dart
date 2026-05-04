import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_translation_service.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:typed_data';

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<dynamic> _appsList = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _mockApps = [
    {'name': 'Instagram', 'icon': FontAwesomeIcons.instagram, 'color': const Color(0xFFE1306C), 'category': 'social', 'blocked': true},
    {'name': 'TikTok', 'icon': FontAwesomeIcons.tiktok, 'color': Colors.black, 'category': 'social', 'blocked': true},
    {'name': 'YouTube', 'icon': FontAwesomeIcons.youtube, 'color': const Color(0xFFFF0000), 'category': 'entertainment', 'blocked': false},
    {'name': 'Telegram', 'icon': FontAwesomeIcons.telegram, 'color': const Color(0xFF24A1DE), 'category': 'communication', 'blocked': false},
    {'name': 'WhatsApp', 'icon': FontAwesomeIcons.whatsapp, 'color': const Color(0xFF25D366), 'category': 'communication', 'blocked': false},
    {'name': 'PUBG Mobile', 'icon': FontAwesomeIcons.gamepad, 'color': const Color(0xFFFBC02D), 'category': 'games', 'blocked': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> blockedPackages = prefs.getStringList('blocked_apps') ?? [];

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        List<Application> apps = await DeviceApps.getInstalledApplications(
          includeAppIcons: true,
          includeSystemApps: true,
          onlyAppsWithLaunchIntent: true,
        );
        
        setState(() {
          _appsList = apps.map((app) {
            return {
              'package': app.packageName,
              'name': app.appName,
              'icon': (app is ApplicationWithIcon) ? app.icon : null,
              'color': const Color(0xFF007AFF),
              'category': 'other',
              'blocked': blockedPackages.contains(app.packageName),
              'isReal': true,
            };
          }).toList();
          
          _appsList.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _appsList = List.from(_mockApps);
          _isLoading = false;
        });
      }
    } else {
      // Show mock list for Web/iOS
      setState(() {
        _appsList = List.from(_mockApps);
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _displayList {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _appsList;
    
    return _appsList.where((app) {
      final name = (app as Map)['name'].toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppTranslationService();
    return ValueListenableBuilder<String>(
      valueListenable: lang.languageNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    Text(
                      lang.translate('block_list.title'), 
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.8)
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        style: GoogleFonts.inter(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: lang.translate('block_list.search_hint'),
                          hintStyle: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontSize: 15),
                          prefixIcon: const Icon(CupertinoIcons.search, color: Color(0xFF8E8E93), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF007AFF), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang.translate('block_list.info_banner'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // App List
                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CupertinoActivityIndicator()))
                    else if (_displayList.isEmpty)
                      _buildEmptyState(lang)
                    else
                      ...List.generate(
                        _displayList.length,
                        (index) => _buildAppTile(_displayList[index], lang),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppTranslationService lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.search, size: 60, color: const Color(0xFF8E8E93).withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(lang.translate('block_list.not_found'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF8E8E93))),
        ],
      ),
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app, AppTranslationService lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: app['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: app['isReal'] == true && app['icon'] != null
                ? Image.memory(app['icon'] as Uint8List, width: 22, height: 22)
                : FaIcon(app['icon'], color: app['color'], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app['name'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                Text(
                  lang.translate('block_list.categories.${app['category']}'), 
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: app['blocked'],
            activeColor: Theme.of(context).primaryColor,
            onChanged: (val) async {
              setState(() {
                app['blocked'] = val;
              });
              
              if (app['isReal'] == true) {
                final prefs = await SharedPreferences.getInstance();
                List<String> blockedPackages = prefs.getStringList('blocked_apps') ?? [];
                
                if (val) {
                  if (!blockedPackages.contains(app['package'])) {
                    blockedPackages.add(app['package']);
                  }
                } else {
                  blockedPackages.remove(app['package']);
                }
                
                await prefs.setStringList('blocked_apps', blockedPackages);
              }
            },
          ),
        ],
      ),
    );
  }
}
