// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:flutter_gallery/screens/real_time_transcriber.dart';

// import '../services/llm_service.dart';

// class TranscribingScreen extends StatefulWidget {
//   final String systemPrompt;
//   final RealTimeTranscriber transcriber;
//   const TranscribingScreen({
//     Key? key,
//     required this.transcriber,
//     required this.systemPrompt,
//   }) : super(key: key);

//   @override
//   State<TranscribingScreen> createState() => _TranscribingScreenState();
// }

// class _TranscribingScreenState extends State<TranscribingScreen> {
//   String? _transcript;
//   String? _llmResponse;
//   Map<String, dynamic>? _parsedLlmJson;
//   bool _isGeneratingLlm = false;
//   StreamSubscription<InferenceResult>? _llmStreamSub;
//   Timer? _dotTimer;
//   int _dotCount = 0;

//   @override
//   void initState() {
//     super.initState();
//     _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
//       setState(() {
//         _dotCount = (_dotCount + 1) % 4;
//       });
//     });
//     WidgetsBinding.instance.addPostFrameCallback((_) => _startTranscription());
//   }

//   Future<void> _startTranscription() async {
//     try {
//       final result = await widget.transcriber.stop();
//       setState(() {
//         _transcript = result;
//       });
//     } catch (e) {
//       setState(() {
//         _transcript = 'Transcription error: $e';
//       });
//     }
//     if (_transcript != null && _transcript!.isNotEmpty) {
//       final promptWithSystem = "${widget.systemPrompt}\n${_transcript}";
//       _generateLlmResponse(promptWithSystem);
//     }

//     _dotTimer?.cancel();
//   }

//   Future<void> _generateLlmResponse(String prompt) async {
//     setState(() {
//       _isGeneratingLlm = true;
//       _llmResponse = null;
//     });
//     await _llmStreamSub?.cancel();
//     _llmStreamSub = LlmService.getInferenceStream().listen(
//       (result) {
//         setState(() {
//           if (_llmResponse == null) _llmResponse = '';
//           _llmResponse = _llmResponse! + result.partialResult;
//           if (result.isDone) {
//             _isGeneratingLlm = false;
//             try {
//               _parsedLlmJson = _llmResponse != null
//                   ? _parseJson(_llmResponse!)
//                   : null;
//             } catch (e) {
//               _parsedLlmJson = null;
//             }
//           }
//         });
//       },
//       onError: (error) {
//         setState(() {
//           _isGeneratingLlm = false;
//           _llmResponse = 'LLM error: $error';
//         });
//       },
//     );
//     await LlmService.generateResponse(prompt);
//   }

//   Map<String, dynamic>? _parseJson(String text) {
//     try {
//       // Remove any leading/trailing whitespace and extra text
//       final jsonStart = text.indexOf('{');
//       final jsonEnd = text.lastIndexOf('}');
//       if (jsonStart == -1 || jsonEnd == -1) return null;
//       final jsonString = text.substring(jsonStart, jsonEnd + 1).trim();
//       return json.decode(jsonString) as Map<String, dynamic>;
//     } catch (e) {
//       return null;
//     }
//   }

//   Widget _buildHumanReadableJson(Map<String, dynamic> json) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: <Widget>[
//         const Text(
//           'Human-Readable Summary:',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 16),
//         ..._buildJsonSections(json),
//       ],
//     );
//   }

//   List<Widget> _buildJsonSections(Map<String, dynamic> json) {
//     List<Widget> widgets = <Widget>[];
//     json.forEach((key, value) {
//       widgets.add(
//         Text(
//           key,
//           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//         ),
//       );
//       widgets.add(const SizedBox(height: 8));
//       if (value is Map) {
//         widgets.addAll(_buildJsonSections(Map<String, dynamic>.from(value)));
//       } else if (value is List) {
//         if (value.isEmpty) {
//           widgets.add(const Text('None', style: TextStyle(fontSize: 16)));
//         } else {
//           widgets.add(
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: value
//                   .map<Widget>(
//                     (item) =>
//                         Text('- $item', style: const TextStyle(fontSize: 16)),
//                   )
//                   .toList(),
//             ),
//           );
//         }
//       } else {
//         widgets.add(
//           Text(
//             value == null ? 'None' : value.toString(),
//             style: const TextStyle(fontSize: 16),
//           ),
//         );
//       }
//       widgets.add(const SizedBox(height: 12));
//     });
//     return widgets;
//   }

//   @override
//   void dispose() {
//     _dotTimer?.cancel();
//     _llmStreamSub?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     String dots = '.' * _dotCount;
//     return Scaffold(
//       appBar: AppBar(title: const Text('Transcribing')),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (_transcript == null)
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 32),
//                 child: Text(
//                   'Transcribing' + dots,
//                   style: const TextStyle(
//                     fontSize: 32,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     if (_transcript != null) ...[
//                       const Text(
//                         'Transcript:',
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.grey[100],
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: SelectableText(
//                           _transcript!,
//                           style: const TextStyle(fontSize: 18),
//                         ),
//                       ),
//                       const SizedBox(height: 32),
//                       const Text(
//                         'LLM Response:',
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.grey[50],
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: _isGeneratingLlm
//                             ? const Text(
//                                 'Generating...',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   color: Colors.grey,
//                                 ),
//                               )
//                             : (_llmResponse != null
//                                   ? Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         SelectableText(
//                                           _llmResponse!,
//                                           style: const TextStyle(fontSize: 18),
//                                         ),
//                                         const SizedBox(height: 32),
//                                         if (_parsedLlmJson != null)
//                                           _buildHumanReadableJson(
//                                             _parsedLlmJson!,
//                                           )
//                                         else if (_llmResponse != null &&
//                                             !_isGeneratingLlm)
//                                           const Text(
//                                             'Could not parse LLM response as JSON.',
//                                             style: TextStyle(
//                                               fontSize: 16,
//                                               color: Colors.red,
//                                             ),
//                                           ),
//                                       ],
//                                     )
//                                   : const Text(
//                                       'No response',
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         color: Colors.grey,
//                                       ),
//                                     )),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
