// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../services/huggingface_token_verifier.dart';

// class HuggingFaceTokenSettingsScreen extends StatefulWidget {
//   const HuggingFaceTokenSettingsScreen({Key? key}) : super(key: key);

//   @override
//   State<HuggingFaceTokenSettingsScreen> createState() => _HuggingFaceTokenSettingsScreenState();
// }

// class _HuggingFaceTokenSettingsScreenState extends State<HuggingFaceTokenSettingsScreen> {
//   final _controller = TextEditingController();
//   bool _saving = false;
//   String? _savedToken;
//   bool? _isTokenValid;
//   bool _verifying = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadToken();
//   }

//   Future<void> _loadToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _savedToken = prefs.getString('huggingface_token');
//       _controller.text = _savedToken ?? '';
//     });
//   }

//   Future<void> _saveToken() async {
//     setState(() {
//       _saving = true;
//       _isTokenValid = null;
//     });
//     final token = _controller.text.trim();
//     final valid = await HuggingFaceTokenVerifier.verifyToken(token);
//     if (valid) {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('huggingface_token', token);
//       setState(() {
//         _savedToken = token;
//         _isTokenValid = true;
//         _saving = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Token saved and verified!')),
//       );
//     } else {
//       setState(() {
//         _isTokenValid = false;
//         _saving = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Invalid Hugging Face token!'), backgroundColor: Colors.red),
//       );
//     }
//   }

//   Future<void> _verifyToken() async {
//     setState(() => _verifying = true);
//     final token = _controller.text.trim();
//     final valid = await HuggingFaceTokenVerifier.verifyToken(token);
//     setState(() {
//       _isTokenValid = valid;
//       _verifying = false;
//     });
//     if (valid) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Token is valid!'), backgroundColor: Colors.green),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Invalid Hugging Face token!'), backgroundColor: Colors.red),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Hugging Face Token')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Enter your Hugging Face access token:'),
//             const SizedBox(height: 12),
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 border: const OutlineInputBorder(),
//                 labelText: 'Access Token',
//                 suffixIcon: _verifying
//                     ? const Padding(
//                         padding: EdgeInsets.all(8.0),
//                         child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
//                       )
//                     : _isTokenValid == null
//                         ? null
//                         : (_isTokenValid!
//                             ? const Icon(Icons.check_circle, color: Colors.green)
//                             : const Icon(Icons.error, color: Colors.red)),
//               ),
//               obscureText: true,
//               enableSuggestions: false,
//               autocorrect: false,
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 ElevatedButton(
//                   onPressed: _saving ? null : _saveToken,
//                   child: _saving ? const CircularProgressIndicator() : const Text('Save & Verify'),
//                 ),
//                 const SizedBox(width: 12),
//                 OutlinedButton(
//                   onPressed: _verifying ? null : _verifyToken,
//                   child: const Text('Verify Only'),
//                 ),
//               ],
//             ),
//             if (_savedToken != null && _savedToken!.isNotEmpty) ...[
//               const SizedBox(height: 24),
//               const Text('Current token:'),
//               SelectableText(_savedToken!, style: const TextStyle(fontFamily: 'monospace')),
//             ]
//           ],
//         ),
//       ),
//     );
//   }
// }
