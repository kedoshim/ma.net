import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/services/endpoint_priority_resolver.dart';
import 'package:manet_desktop/services/qr_code_cache_service.dart';

class StartupConnectionState {
  final ConnectionSnapshot? connectionSnapshot;
  final DiagnosticsSnapshot? diagnosticsSnapshot;
  final ConnectionInfo? selectedConnection;
  final String? qrEndpointUrl;
  final ImageProvider? qrImage;
  final bool isLoadingConnections;
  final bool isLoadingDiagnostics;
  final bool isLoadingQr;
  final bool isUsingStaleEndpoint;

  const StartupConnectionState({
    this.connectionSnapshot,
    this.diagnosticsSnapshot,
    this.selectedConnection,
    this.qrEndpointUrl,
    this.qrImage,
    this.isLoadingConnections = false,
    this.isLoadingDiagnostics = false,
    this.isLoadingQr = false,
    this.isUsingStaleEndpoint = false,
  });

  StartupConnectionState copyWith({
    ConnectionSnapshot? connectionSnapshot,
    DiagnosticsSnapshot? diagnosticsSnapshot,
    ConnectionInfo? selectedConnection,
    String? qrEndpointUrl,
    ImageProvider? qrImage,
    bool? isLoadingConnections,
    bool? isLoadingDiagnostics,
    bool? isLoadingQr,
    bool? isUsingStaleEndpoint,
  }) {
    return StartupConnectionState(
      connectionSnapshot: connectionSnapshot ?? this.connectionSnapshot,
      diagnosticsSnapshot: diagnosticsSnapshot ?? this.diagnosticsSnapshot,
      selectedConnection: selectedConnection ?? this.selectedConnection,
      qrEndpointUrl: qrEndpointUrl ?? this.qrEndpointUrl,
      qrImage: qrImage ?? this.qrImage,
      isLoadingConnections: isLoadingConnections ?? this.isLoadingConnections,
      isLoadingDiagnostics: isLoadingDiagnostics ?? this.isLoadingDiagnostics,
      isLoadingQr: isLoadingQr ?? this.isLoadingQr,
      isUsingStaleEndpoint: isUsingStaleEndpoint ?? this.isUsingStaleEndpoint,
    );
  }
}

class StartupConnectionPipeline {
  static const _prefsKey = 'startup_last_connection';

  final HostApiService api;
  final EndpointPriorityResolver resolver;
  final QrCodeCacheService qrCache;
  final ValueNotifier<StartupConnectionState> state;

  late final Future<SharedPreferences> _prefsFuture;
  final Stopwatch _startupWatch = Stopwatch();
  bool _firstQrRendered = false;

  StartupConnectionPipeline({
    required this.api,
    EndpointPriorityResolver? resolver,
    QrCodeCacheService? qrCache,
  }) : resolver = resolver ?? EndpointPriorityResolver(),
       qrCache = qrCache ?? QrCodeCacheService.instance,
       state = ValueNotifier(const StartupConnectionState()) {
    _prefsFuture = SharedPreferences.getInstance();
  }

  Future<void> initialize() async {
    _startupWatch.start();
    _setState(
      state.value.copyWith(
        isLoadingConnections: true,
        isLoadingDiagnostics: true,
        isLoadingQr: true,
      ),
    );

    final previousConnection = await _loadPreviousConnection();
    if (previousConnection != null) {
      final endpoint = api.getQrCodeUrl(previousConnection.id);
      _setState(
        state.value.copyWith(
          selectedConnection: previousConnection,
          qrEndpointUrl: endpoint,
          isUsingStaleEndpoint: true,
        ),
      );
      _loadQrImage(endpoint, keepPlaceholder: true);
    }

    unawaited(_warmConnectionInfo(previousConnection));
    unawaited(_refreshConnections(previousConnection));
    unawaited(_refreshDiagnostics());
  }

  void dispose() {
    state.dispose();
  }

  Future<void> selectConnection(String connectionId) async {
    if (connectionId.isEmpty) return;
    _setState(state.value.copyWith(isLoadingConnections: true));

    try {
      final selectedConnection = await api.selectConnection(connectionId);
      final endpoint = api.getQrCodeUrl(selectedConnection.id);
      _setState(
        state.value.copyWith(
          selectedConnection: selectedConnection,
          qrEndpointUrl: endpoint,
          isLoadingConnections: false,
          isUsingStaleEndpoint: false,
        ),
      );
      _saveConnection(selectedConnection);
      await _loadQrImage(endpoint);
    } catch (e) {
      debugPrint('[STARTUP PIPELINE] selectConnection failed: $e');
      _setState(state.value.copyWith(isLoadingConnections: false));
    } finally {
      unawaited(_refreshConnections(state.value.selectedConnection));
      unawaited(_refreshDiagnostics());
    }
  }

  Future<void> refreshDiagnostics() async {
    await _refreshDiagnostics();
  }

  Future<void> _warmConnectionInfo(ConnectionInfo? previousConnection) async {
    try {
      final info = await api.fetchConnectionInfo();
      if (info.url.isEmpty) return;

      final endpoint = api.getQrCodeUrl(info.id);
      final existing = state.value.selectedConnection;
      final shouldUpdate =
          existing == null ||
          existing.id != info.id ||
          existing.url != info.url;

      if (shouldUpdate) {
        _setState(
          state.value.copyWith(
            selectedConnection: info,
            qrEndpointUrl: endpoint,
            isUsingStaleEndpoint: false,
          ),
        );
        await _loadQrImage(endpoint);
      }
    } catch (e) {
      debugPrint('[STARTUP PIPELINE] quick connection info failed: $e');
    }
  }

  Future<void> _refreshConnections(ConnectionInfo? previousConnection) async {
    final start = Stopwatch()..start();
    try {
      final snapshot = await api.fetchConnections();
      var selected = state.value.selectedConnection;
      final best = resolver.selectBestConnection(
        snapshot.connections,
        previousConnection: previousConnection ?? selected,
      );

      if (best != null) {
        final endpoint = api.getQrCodeUrl(best.id);
        final shouldUpdateEndpoint = endpoint != state.value.qrEndpointUrl;
        _setState(
          state.value.copyWith(
            connectionSnapshot: snapshot,
            selectedConnection: best,
            qrEndpointUrl: endpoint,
            isLoadingConnections: false,
            isUsingStaleEndpoint: false,
          ),
        );

        if (shouldUpdateEndpoint || state.value.qrImage == null) {
          await _loadQrImage(endpoint);
        }
        await _saveConnection(best);
      } else {
        _setState(
          state.value.copyWith(
            connectionSnapshot: snapshot,
            isLoadingConnections: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('[STARTUP PIPELINE] connection discovery failed: $e');
      _setState(state.value.copyWith(isLoadingConnections: false));
    } finally {
      start.stop();
      if (kDebugMode) {
        debugPrint(
          '[STARTUP PIPELINE] interface scan duration: ${start.elapsedMilliseconds}ms',
        );
      }
    }
  }

  Future<void> _refreshDiagnostics() async {
    return;
    final start = Stopwatch()..start();
    _setState(state.value.copyWith(isLoadingDiagnostics: true));
    try {
      final diagnostics = await api.fetchDiagnostics();
      _setState(
        state.value.copyWith(
          diagnosticsSnapshot: diagnostics,
          isLoadingDiagnostics: false,
        ),
      );
    } catch (e) {
      debugPrint('[STARTUP PIPELINE] diagnostics refresh failed: $e');
      _setState(state.value.copyWith(isLoadingDiagnostics: false));
    } finally {
      start.stop();
      if (kDebugMode) {
        debugPrint(
          '[STARTUP PIPELINE] diagnostics duration: ${start.elapsedMilliseconds}ms',
        );
      }
    }
  }

  Future<void> _loadQrImage(
    String endpoint, {
    bool keepPlaceholder = false,
  }) async {
    if (endpoint.isEmpty) return;
    if (qrCache.hasCachedImage(endpoint)) {
      _setState(
        state.value.copyWith(
          qrImage: qrCache.imageForUrl(endpoint),
          isLoadingQr: false,
        ),
      );
      _logFirstQrIfNeeded();
      return;
    }

    if (!keepPlaceholder) {
      _setState(state.value.copyWith(isLoadingQr: true));
    }

    final start = Stopwatch()..start();
    try {
      final bytes = await qrCache.loadQrBytes(endpoint);
      if (state.value.qrEndpointUrl == endpoint) {
        _setState(
          state.value.copyWith(qrImage: MemoryImage(bytes), isLoadingQr: false),
        );
        _logFirstQrIfNeeded();
      }
    } catch (e) {
      debugPrint('[STARTUP PIPELINE] QR generation failed: $e');
      _setState(state.value.copyWith(isLoadingQr: false));
    } finally {
      start.stop();
      if (kDebugMode) {
        debugPrint(
          '[STARTUP PIPELINE] QR generation duration: ${start.elapsedMilliseconds}ms',
        );
      }
    }
  }

  Future<ConnectionInfo?> _loadPreviousConnection() async {
    try {
      final prefs = await _prefsFuture;
      final rawJson = prefs.getString(_prefsKey);
      if (rawJson == null) return null;
      final data = json.decode(rawJson) as Map<String, dynamic>;
      return ConnectionInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveConnection(ConnectionInfo connection) async {
    try {
      final prefs = await _prefsFuture;
      final rawJson = json.encode(connection.toJson());
      await prefs.setString(_prefsKey, rawJson);
    } catch (_) {
      // ignore write failures
    }
  }

  void _setState(StartupConnectionState next) {
    state.value = next;
  }

  void _logFirstQrIfNeeded() {
    if (!_firstQrRendered) {
      _firstQrRendered = true;
      _startupWatch.stop();
      if (kDebugMode) {
        debugPrint(
          '[STARTUP PIPELINE] time to first QR: ${_startupWatch.elapsedMilliseconds}ms',
        );
      }
    }
  }
}
