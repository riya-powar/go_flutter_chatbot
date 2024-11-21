import 'dart:convert';
import 'dart:html'; // For Web - Instead of dart:io
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart'; // Import for web
import 'package:flutter/foundation.dart'; // For kIsWeb

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  dynamic _image; // Using dynamic type for cross-platform compatibility
  bool isLoading = false; // For loading state

  // Function to pick an image from the gallery (web-specific)
  Future<void> _pickImage() async {
    if (kIsWeb) {
      // For web, use image_picker_web
      var file = await ImagePickerWeb.getImageAsFile();
      if (file != null) {
        setState(() {
          _image = file; // No need to cast as File
        });
      }
    } else {
      // For mobile/desktop, use regular image_picker
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = pickedFile; // Use File from ImagePicker
        });
      }
    }
  }

  // Function to send the image to the server
Future<void> _sendImage() async {
  if (_image == null) return;

  // Convert image to base64 format (for web, it's compatible with File)
  List<int> bytes;

  if (kIsWeb) {
    // Web-specific: Convert the image file to bytes
    final reader = FileReader();
    reader.readAsArrayBuffer(_image);
    await reader.onLoadEnd.first; // Wait until the file is fully read
    bytes = reader.result as List<int>;
    if (bytes == null) {
      print("Error: Image could not be read.");
      return;
    }
  } else {
    // Mobile/Desktop-specific: Use File's readAsBytes
    bytes = await _image.readAsBytes();
  }

  String base64Image = base64Encode(bytes);

  setState(() {
    messages.add({
      'sender': 'User',
      'message': 'Image sent',
      'isImage': true,
      'image': base64Image, // Sending base64 for now
    });
  });

  final url = Uri.parse('http://localhost:8080/chat');

  // Updated request body to send an array of messages
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'model': 'llama-3.2-11b-vision-preview',  // Ensure correct model name
      'messages': [
        {
          'role': 'user',
          'content': base64Image, // Include the base64 image directly in the content
        }
      ],
    }),
  );

  if (response.statusCode == 200) {
    var data = json.decode(response.body);
  if (data != null && data.containsKey('response')) {
    setState(() {
      messages.add({
        'sender': 'Gemini',
        'message': data['response'] ?? 'No response from API',
        'isImage': false,
      });
    });
  } else {
    setState(() {
      messages.add({
        'sender': 'Gemini',
        //'message': 'Invalid API response',
        'message': data['choices'][0]['message']['content'],
        'isImage': false,
      });
    });
  }
  } else {
    setState(() {
      messages.add({
        'sender': 'Gemini',
        'message': 'Error: Unable to get a response',
        'isImage': false,
      });
    });
  }
}

  // Function to send text message to the server
  Future<void> _sendMessage(String message) async {
    setState(() {
      messages.add({
        'sender': 'User',
        'message': message ?? 'Default message',
        'isImage': false,
      });
    });

    final url = Uri.parse('http://localhost:8080/chat');

    // Constructing the request body with the correct format
    final requestBody = json.encode({
      'model': 'llama3-8b-8192',  // Ensure you provide the correct model name
      'messages': [
        {
          'role': 'user',
          'content': message,
        }
      ],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      setState(() {
        messages.add({
          'sender': 'Gemini',
          'message': data['choices'][0]['message']['content'],
          'isImage': false,
        });
      });
    } else {
      setState(() {
        messages.add({
          'sender': 'Gemini',
          'message': 'Error: Unable to get a response',
          'isImage': false,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 231, 174, 246),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text(
                "CHAT BOT",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    bool isUserMessage = message['sender'] == 'User';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      child: Row(
                        children: [
                          isUserMessage
                              ? CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  child: Icon(Icons.person, color: Colors.white),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.account_circle, color: Colors.white),
                                ),
                          SizedBox(width: 10),
                          Flexible(
                            child: message['isImage']
                              ? Image.memory(
                                  base64Decode(message['image']),
                                  width: 200, // Adjust width/height as needed
                                  height: 200,
                                )
                              : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isUserMessage ? Colors.purple : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: MarkdownBody(
                                    data: message['message'], 
                                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context).copyWith(
                                    textTheme: TextTheme(
                                      bodyMedium: TextStyle(
                                                    fontSize: 16, // Ensure fontSize is defined for bodyMedium
                                                    color: isUserMessage ? Colors.white : Colors.black, // Optional: Change text color
                                                  ),
                                    ),
                                    )),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 178, 243, 243),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 5,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(hintText: 'Type a message'),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () {
                          String message = _controller.text ?? '';
                          if (message.isNotEmpty) {
                            _sendMessage(message);
                            _controller.clear();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.image),
                        onPressed: () async {
                          await _pickImage(); // Pick the image
                          if (_image != null) {
                            _sendImage(); // Send the image once it's picked
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
