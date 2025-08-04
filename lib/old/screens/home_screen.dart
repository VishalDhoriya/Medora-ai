// import 'package:flutter/material.dart';
// import 'model_manager_screen.dart';
// import 'chat_screen.dart';
// import 'huggingface_token_settings_screen.dart';
// import 'audio_recorder_screen.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {

//   int _selectedIndex = 0;

//   final List<Widget> _screens = [
//     const ModelManagerScreen(),
//     const ChatScreen(),
//     const AudioRecorderScreen(),
//   ];

//   final List<String> _titles = [
//     'Model Manager',
//     'LLM Chat',
//     'Audio Recorder',
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(_titles[_selectedIndex]),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         elevation: 2,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.vpn_key),
//             tooltip: 'Hugging Face Token',
//             onPressed: () {
//               Navigator.of(context).push(
//                 MaterialPageRoute(
//                   builder: (context) =>
//                       // Import at top: import 'huggingface_token_settings_screen.dart';
//                       // ignore: prefer_const_constructors
//                       HuggingFaceTokenSettingsScreen(),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//       body: IndexedStack(
//         index: _selectedIndex,
//         children: _screens,
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _selectedIndex,
//         onTap: (index) {
//           setState(() {
//             _selectedIndex = index;
//           });
//         },
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.storage),
//             label: 'Models',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.chat),
//             label: 'Chat',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.mic),
//             label: 'Recorder',
//           ),
//         ],
//       ),
//     );
//   }
// }
