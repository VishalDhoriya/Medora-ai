import 'package:http/http.dart' as http;

class HuggingFaceTokenVerifier {
  /// Verifies the Hugging Face token by making a request to the user info endpoint.
  /// Returns true if the token is valid, false otherwise.
  static Future<bool> verifyToken(String token) async {
    if (token.isEmpty) return false;
    final url = Uri.parse('https://huggingface.co/api/whoami-v2');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        // Optionally, parse user info: jsonDecode(response.body)
        return true;
      }
      return false;
    } catch (e) {
      print('[HuggingFaceTokenVerifier] Error verifying token: $e');
      return false;
    }
  }
}
