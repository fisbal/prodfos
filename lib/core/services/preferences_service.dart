import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  late SharedPreferences _prefs;

  bool _nightMode = false;
  bool _rememberPosition = true;
  double _defaultZoom = 1.0;
  String _scrollDirection = 'vertical';
  String _pageLayout = 'continuous';
  double _pageSpacing = 2.0;
  bool _showPageCount = true;
  bool _showScrollHead = true;
  String _aiApiKey = '';
  String _aiProvider = 'anthropic';

  bool get nightMode => _nightMode;
  bool get rememberPosition => _rememberPosition;
  double get defaultZoom => _defaultZoom;
  String get scrollDirection => _scrollDirection;
  String get pageLayout => _pageLayout;
  double get pageSpacing => _pageSpacing;
  bool get showPageCount => _showPageCount;
  bool get showScrollHead => _showScrollHead;
  String get aiApiKey => _aiApiKey;
  String get aiProvider => _aiProvider;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _nightMode = _prefs.getBool('nightMode') ?? false;
    _rememberPosition = _prefs.getBool('rememberPosition') ?? true;
    _defaultZoom = _prefs.getDouble('defaultZoom') ?? 1.0;
    _scrollDirection = _prefs.getString('scrollDirection') ?? 'vertical';
    _pageLayout = _prefs.getString('pageLayout') ?? 'continuous';
    _pageSpacing = _prefs.getDouble('pageSpacing') ?? 2.0;
    _showPageCount = _prefs.getBool('showPageCount') ?? true;
    _showScrollHead = _prefs.getBool('showScrollHead') ?? true;
    _aiApiKey = _prefs.getString('aiApiKey') ?? '';
    _aiProvider = _prefs.getString('aiProvider') ?? 'anthropic';
  }

  set nightMode(bool v) { _nightMode = v; _prefs.setBool('nightMode', v); notifyListeners(); }
  set rememberPosition(bool v) { _rememberPosition = v; _prefs.setBool('rememberPosition', v); notifyListeners(); }
  set defaultZoom(double v) { _defaultZoom = v; _prefs.setDouble('defaultZoom', v); notifyListeners(); }
  set scrollDirection(String v) { _scrollDirection = v; _prefs.setString('scrollDirection', v); notifyListeners(); }
  set pageLayout(String v) { _pageLayout = v; _prefs.setString('pageLayout', v); notifyListeners(); }
  set pageSpacing(double v) { _pageSpacing = v; _prefs.setDouble('pageSpacing', v); notifyListeners(); }
  set showPageCount(bool v) { _showPageCount = v; _prefs.setBool('showPageCount', v); notifyListeners(); }
  set showScrollHead(bool v) { _showScrollHead = v; _prefs.setBool('showScrollHead', v); notifyListeners(); }
  set aiApiKey(String v) { _aiApiKey = v; _prefs.setString('aiApiKey', v); notifyListeners(); }
  set aiProvider(String v) { _aiProvider = v; _prefs.setString('aiProvider', v); notifyListeners(); }
}
