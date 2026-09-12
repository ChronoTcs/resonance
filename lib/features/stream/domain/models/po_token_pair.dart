/// Proof-of-Origin token pair returned by any [IPlatformPoTokenService].
class PoTokenPair {
  final String playerPoToken;
  final String streamPoToken;

  const PoTokenPair({
    required this.playerPoToken,
    required this.streamPoToken,
  });
}
