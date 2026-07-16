import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:energy_application/auth-pages/signin.dart';
import 'package:energy_application/user-pages/home_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accessKeyController = TextEditingController();

  Widget _buildInputField(
    String label,
    String hint,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: type,
            cursorColor: Colors.green,
            style: const TextStyle(color: Colors.green, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.green, fontSize: 14),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green, width: 2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                Container(
                  width: 200,
                  height: 200,
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/signin_image.png',
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person_add,
                      size: 100,
                      color: Colors.green,
                    ),
                  ),
                ),
                const Text(
                  "Create Your Account",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  "Username:",
                  "Enter your name",
                  _usernameController,
                ),
                _buildInputField(
                  "Email Address:",
                  "example@mail.com",
                  _emailController,
                  type: TextInputType.emailAddress,
                ),
                _buildInputField(
                  "Mobile Number:",
                  "07xxxxxxxx",
                  _mobileController,
                  type: TextInputType.phone,
                ),
                _buildInputField(
                  "Existing Bill Account Number:",
                  "CEB_xxxxxx_xxxxxx",
                  _accountNumberController,
                ),
                _buildInputField(
                  "Access Key:",
                  "* * * * * *",
                  _accessKeyController,
                  isPassword: true,
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF67D66A), Color(0xFF43730B)],
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });
                        if (_usernameController.text.isEmpty ||
                            _emailController.text.isEmpty ||
                            _mobileController.text.isEmpty ||
                            _accountNumberController.text.isEmpty ||
                            _accessKeyController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill all fields"),
                            ),
                          );
                          setState(() {
                            _isLoading = false;
                          });
                          return;
                        } else {
                          try {
                            setState(() {
                              _isLoading = true;
                            });
                            UserCredential userCredential = await FirebaseAuth
                                .instance
                                .createUserWithEmailAndPassword(
                                  email: _emailController.text.trim(),
                                  password: _accessKeyController.text.trim(),
                                );

                            String uid = userCredential.user!.uid;
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .set({
                                  'username': _usernameController.text.trim(),
                                  'email': _emailController.text.trim(),
                                  'mobile': _mobileController.text.trim(),
                                  'accountNumber': _accountNumberController.text
                                      .trim(),
                                  'createdAt': Timestamp.now(),
                                });
                            setState(() {
                              _isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Account created successfully"),
                              ),
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomePage(),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            setState(() {
                              _isLoading = false;
                            });
                            String message = "Signup failed";

                            if (e.code == 'email-already-in-use') {
                              message = "Email already in use";
                            } else if (e.code == 'weak-password') {
                              message = "Password is too weak";
                            }
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Something went wrong"),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        "CREATE ACCOUNT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const Signin()),
                  ),
                  child: const Text(
                    "Already have an account? Sign In",
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
