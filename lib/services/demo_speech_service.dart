import 'dart:async';

class DemoSpeechService {
  static const String _demoSpeechTranscript = """Doctor: Good morning! How are you feeling today?

Patient: Good morning, Doctor. I'm not feeling great. I've been having a sore throat for about three days now, and it's been getting worse. I also have a fever and feel really tired.

Doctor: I'm sorry to hear that. Let me ask you a few questions to better understand your symptoms. When did the sore throat first start?

Patient: It started on Sunday morning. At first, it was just a little scratchy, but now it hurts when I swallow.

Doctor: I see. And you mentioned having a fever. Have you taken your temperature?

Patient: Yes, this morning it was 101.2 degrees Fahrenheit.

Doctor: That's definitely a fever. What about other symptoms? Do you have a cough, runny nose, or headache?

Patient: I have a slight cough, but it's not too bad. No runny nose, but I do have a mild headache. And I've been feeling very fatigued - I can barely get out of bed.

Doctor: Thank you for those details. Have you been around anyone who's been sick recently?

Patient: Well, my daughter had a cold last week, but she seemed to get better pretty quickly.

Doctor: That could be related. Let me examine you now. I'm going to look at your throat first.

Doctor: Your throat is quite red and I can see some swelling. Your lymph nodes in your neck are also swollen. Let me check your temperature again and listen to your breathing.

Doctor: Your temperature is indeed elevated at 101.2. Your breathing sounds clear, which is good news. Based on your symptoms - the sore throat, fever, swollen lymph nodes, and fatigue - this appears to be a viral upper respiratory infection.

Patient: Is that serious? Do I need antibiotics?

Doctor: The good news is that this type of viral infection usually resolves on its own within 7-10 days. Antibiotics won't help because it's caused by a virus, not bacteria. However, I can prescribe some medications to help you feel more comfortable while you recover.

Patient: What can I do to feel better?

Doctor: I'm going to recommend several things. First, for the pain and fever, you can take acetaminophen 650mg every 6 hours, or ibuprofen 400mg every 6-8 hours. Don't exceed the maximum daily doses. For your sore throat, try warm salt water gargles - mix half a teaspoon of salt in a cup of warm water and gargle 3-4 times a day.

Patient: Okay, I can do that. Anything else?

Doctor: Yes, make sure you get plenty of rest and stay well hydrated. Drink warm liquids like tea with honey, or warm broth. Avoid alcohol and smoking if you do either. You should also use a humidifier or breathe steam from a hot shower to help with throat irritation.

Patient: Should I stay home from work?

Doctor: Absolutely. You should stay home until you've been fever-free for at least 24 hours. This will help you recover faster and prevent spreading the infection to others. You're likely contagious right now.

Patient: How will I know if I need to come back?

Doctor: You should return or call if your fever goes above 103 degrees, if you develop severe difficulty swallowing, if you have trouble breathing, if your symptoms worsen after 5-7 days, or if you're not improving after 10 days. Also, if you develop severe headache, neck stiffness, or persistent vomiting, seek care immediately.

Patient: I understand. When should I start feeling better?

Doctor: You should start feeling somewhat better within 2-3 days, especially with the fever and pain medications. The sore throat may take 5-7 days to fully resolve. Remember, this is a viral infection, so your body needs time to fight it off naturally.

Patient: Thank you, Doctor. I'll make sure to rest and follow your instructions.

Doctor: You're welcome. Take care of yourself, get plenty of rest, and don't hesitate to call if you have any concerns or if your symptoms worsen. I hope you feel better soon.""";

  static String getDemoTranscript() {
    return _demoSpeechTranscript;
  }

  /// Simulates the recording process with a timer and returns the demo transcript
  static Future<String> simulateRecordingWithDemoSpeech({
    required Function(int duration) onDurationUpdate,
    required Function() onComplete,
    int recordingDurationSeconds = 10,
  }) async {
    final completer = Completer<String>();
    
    int duration = 0;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      duration++;
      onDurationUpdate(duration);
      
      if (duration >= recordingDurationSeconds) {
        timer.cancel();
        onComplete();
        completer.complete(_demoSpeechTranscript);
      }
    });
    
    return completer.future;
  }

  /// Returns a shorter version for testing
  static String getShortDemoTranscript() {
    return """Doctor: Good morning! How are you feeling today?

Patient: Good morning, Doctor. I've been having a sore throat for about three days now, and it's getting worse. I also have a fever and feel really tired.

Doctor: When did the sore throat first start?

Patient: It started on Sunday morning. At first, it was just scratchy, but now it hurts when I swallow.

Doctor: Have you taken your temperature?

Patient: Yes, this morning it was 101.2 degrees Fahrenheit.

Doctor: Based on your symptoms - the sore throat, fever, and fatigue - this appears to be a viral upper respiratory infection that should resolve within 7-10 days.""";
  }
}
