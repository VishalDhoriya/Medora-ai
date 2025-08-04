// import 'package:flutter/material.dart';
// import 'package:record/record.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:whisper_flutter_new/whisper_flutter_new.dart';
// import '../services/llm_service.dart';
// import 'dart:io';
// import 'dart:async';

// class AudioRecorderScreen extends StatefulWidget {
//   const AudioRecorderScreen({Key? key}) : super(key: key);

//   @override
//   State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
// }

// class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
//   final AudioRecorder _audioRecorder = AudioRecorder();
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   bool isRecording = false;
//   bool isPaused = false;
//   bool showPlayer = false;
//   String? audioPath;
//   bool isPlaying = false;
//   bool canTranscribe = false;
//   String? transcript;
//   bool isTranscribing = false;
//   bool isGeneratingLlm = false;
//   String? llmResponse;
//   StreamSubscription<InferenceResult>? _llmStreamSub;

//   Future<void> _startRecording() async {
//     final hasPermission = await _audioRecorder.hasPermission();
//     if (hasPermission) {
//       final dir = await getApplicationDocumentsDirectory();
//       final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
//       await _audioRecorder.start(
//         const RecordConfig(
//           encoder: AudioEncoder.wav,
//           sampleRate: 16000,
//           bitRate: 128000,
//         ),
//         path: path,
//       );
//       setState(() {
//         isRecording = true;
//         isPaused = false;
//         showPlayer = false;
//         audioPath = null;
//         canTranscribe = false;
//         transcript = null;
//         llmResponse = null;
//       });
//     } else {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Microphone permission denied')),
//         );
//       }
//     }
//   }

//   Future<void> _stopRecording() async {
//     final path = await _audioRecorder.stop();
//     setState(() {
//       isRecording = false;
//       isPaused = false;
//       showPlayer = true;
//       audioPath = path;
//       canTranscribe = true;
//     });
//   }

//   Future<void> _resumeRecording() async {
//     await _audioRecorder.resume();
//     setState(() {
//       isPaused = false;
//     });
//   }

//   Future<void> _pauseRecording() async {
//     await _audioRecorder.pause();
//     setState(() {
//       isPaused = true;
//     });
//   }

//   Future<void> _deleteRecording() async {
//     if (audioPath != null) {
//       final file = File(audioPath!);
//       if (await file.exists()) {
//         await file.delete();
//       }
//     }
//     setState(() {
//       showPlayer = false;
//       audioPath = null;
//       isPlaying = false;
//       canTranscribe = false;
//       transcript = null;
//       llmResponse = null;
//     });
//   }

//   Future<void> _playRecording() async {
//     if (audioPath != null) {
//       try {
//         await _audioPlayer.setFilePath(audioPath!);
//         await _audioPlayer.play();
//         setState(() {
//           isPlaying = true;
//         });
//         _audioPlayer.playerStateStream.listen((state) {
//           if (state.processingState == ProcessingState.completed) {
//             setState(() {
//               isPlaying = false;
//             });
//           }
//         });
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Playback error: $e')),
//           );
//         }
//       }
//     }
//   }

//   Future<void> _transcribeAudio() async {
//     if (audioPath == null) return;
//     setState(() {
//       isTranscribing = true;
//       transcript = null;
//       llmResponse = null;
//     });
//     final whisper = Whisper(
//       model: WhisperModel.base,
//       downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
//     );
//     try {
//       final result = await whisper.transcribe(
//         transcribeRequest: TranscribeRequest(
//           audio: audioPath!,
//           isTranslate: false,
//           isNoTimestamps: true,
//           splitOnWord: false,
//         ),
//       );
//       setState(() {
//         transcript = result.text;
//         isTranscribing = false;
//       });
//       if (result.text.isNotEmpty) {
//         _generateLlmResponse(result.text);
//       }
//     } catch (e) {
//       setState(() {
//         transcript = 'Transcription error: $e';
//         isTranscribing = false;
//       });
//     }
//   }

//   Future<void> _generateLlmResponse(String prompt) async {
//     setState(() {
//       isGeneratingLlm = true;
//       llmResponse = null;
//     });
//     await _llmStreamSub?.cancel();
//     _llmStreamSub = LlmService.getInferenceStream().listen((result) {
//       setState(() {
//         if (llmResponse == null) llmResponse = '';
//         llmResponse = llmResponse! + result.partialResult;
//         if (result.isDone) {
//           isGeneratingLlm = false;
//         }
//       });
//     }, onError: (error) {
//       setState(() {
//         llmResponse = 'LLM error: $error';
//         isGeneratingLlm = false;
//       });
//     });
//     await LlmService.generateResponse(prompt);
//   }

//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     _llmStreamSub?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Audio Recorder')),
//       body: Center(
//         child: showPlayer && audioPath != null
//             ? Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 25),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text('Recorded file path:'),
//                     SelectableText(audioPath!),
//                     const SizedBox(height: 16),
//                     ElevatedButton.icon(
//                       icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
//                       label: Text(isPlaying ? 'Stop Playback' : 'Play'),
//                       onPressed: isPlaying
//                           ? () async {
//                               await _audioPlayer.stop();
//                               setState(() {
//                                 isPlaying = false;
//                               });
//                             }
//                           : _playRecording,
//                     ),
//                     const SizedBox(height: 16),
//                     ElevatedButton.icon(
//                       icon: const Icon(Icons.delete),
//                       label: const Text('Delete'),
//                       onPressed: _deleteRecording,
//                     ),
//                     const SizedBox(height: 16),
//                     ElevatedButton.icon(
//                       icon: const Icon(Icons.text_snippet),
//                       label: const Text('Get Transcript'),
//                       onPressed: canTranscribe && !isTranscribing ? _transcribeAudio : null,
//                     ),
//                     if (isTranscribing) ...[
//                       const SizedBox(height: 16),
//                       const CircularProgressIndicator(),
//                     ],
//                     if (transcript != null) ...[
//                       const SizedBox(height: 16),
//                       Text('Transcript:'),
//                       SelectableText(transcript!),
//                     ],
//                     if (isGeneratingLlm) ...[
//                       const SizedBox(height: 16),
//                       const CircularProgressIndicator(),
//                       const SizedBox(height: 8),
//                       Text('Generating LLM response...'),
//                     ],
//                     if (llmResponse != null) ...[
//                       const SizedBox(height: 16),
//                       Text('LLM Response:'),
//                       SelectableText(llmResponse!),
//                     ],
//                   ],
//                 ),
//               )
//             : Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.mic),
//                     label: const Text('Record'),
//                     onPressed: isRecording ? null : _startRecording,
//                   ),
//                   const SizedBox(height: 16),
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Stop'),
//                     onPressed: isRecording ? _stopRecording : null,
//                   ),
//                   const SizedBox(height: 16),
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.play_arrow),
//                     label: const Text('Resume'),
//                     onPressed: isRecording && isPaused ? _resumeRecording : null,
//                   ),
//                   const SizedBox(height: 16),
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.pause),
//                     label: const Text('Pause'),
//                     onPressed: isRecording && !isPaused ? _pauseRecording : null,
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }
