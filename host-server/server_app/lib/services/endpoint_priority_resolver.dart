import 'package:server_app/services/host_api_service.dart';

class EndpointPriorityResolver {
  static final _ignoredAdapterKeywords = [
    'vpn',
    'teredo',
    'openvpn',
    'hamachi',
    'tunnel',
    'virtual',
    'adapter',
  ];

  ConnectionInfo? selectBestConnection(
    List<ConnectionInfo> candidates, {
    ConnectionInfo? previousConnection,
    bool ignoreVpnAdapters = true,
  }) {
    if (candidates.isEmpty) return null;

    final filtered = candidates.where((candidate) {
      return !_isIgnoredAdapter(candidate, ignoreVpnAdapters);
    }).toList();

    if (filtered.isEmpty) {
      return previousConnection ?? candidates.first;
    }

    if (previousConnection != null) {
      final match = filtered.firstWhere(
        (candidate) =>
            candidate.id == previousConnection.id ||
            candidate.url == previousConnection.url,
        orElse: () => filtered.first,
      );
      if (match.id == previousConnection.id ||
          match.url == previousConnection.url) {
        return match;
      }
    }

    filtered.sort(_compareConnections);
    return filtered.first;
  }

  bool _isIgnoredAdapter(ConnectionInfo connection, bool ignoreVpnAdapters) {
    if (!ignoreVpnAdapters) return false;
    final combined =
        '${connection.kind} ${connection.displayNameKey} ${connection.url}'
            .toLowerCase();
    return _ignoredAdapterKeywords.any(combined.contains);
  }

  int _compareConnections(ConnectionInfo a, ConnectionInfo b) {
    final scoreA = _connectionScore(a);
    final scoreB = _connectionScore(b);
    if (scoreA != scoreB) return scoreA.compareTo(scoreB);
    return a.url.compareTo(b.url);
  }

  int _connectionScore(ConnectionInfo connection) {
    var score = 0;
    final kind = connection.kind.toLowerCase();

    if (kind.contains('wifi')) {
      score += 0;
    } else if (kind.contains('hotspot')) {
      score += 10;
    } else if (kind.contains('ethernet') || kind.contains('cable')) {
      score += 20;
    } else {
      score += 30;
    }

    if (!_isLocalIpv4(connection)) {
      score += 20;
    }

    if (connection.recommended) score -= 8;
    if (connection.preferred) score -= 5;
    if (connection.lastSuccessful) score -= 3;

    return score;
  }

  bool _isLocalIpv4(ConnectionInfo connection) {
    try {
      final host = Uri.parse(connection.url).host;
      if (host.isEmpty) return false;
      if (host == 'localhost' || host == '127.0.0.1') return false;
      return RegExp(
        r'^(10\.|172\.(1[6-9]|2\d|3[0-1])\.|192\.168\.)',
      ).hasMatch(host);
    } catch (_) {
      return false;
    }
  }
}
