import 'package:energy_application/auth-pages/signup.dart';
import 'package:energy_application/user-pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController Email = TextEditingController();
    TextEditingController AccessKey = TextEditingController();
    bool isLoading = false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            width: 300,
                            height: 300,
                            padding: EdgeInsets.all(0),
                            child: Image.asset('assets/signin_image.png'),
                          ),
                        ),
                        Text(
                          "Sign In to Your Account",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                "Email Account: ",
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          TextField(
                            controller: Email,
                            maxLines: 1,
                            cursorColor: Colors.green,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: "ccc@gmail.com",
                              hintStyle: const TextStyle(color: Colors.green),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                "Access Key: ",
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          TextField(
                            maxLines: 1,
                            controller: AccessKey,
                            cursorColor: Colors.green,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: "* * * * * * ",
                              hintStyle: const TextStyle(color: Colors.green),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const Signup()),
                      ),
                      child: const Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 103, 214, 106),
                              Color.fromARGB(255, 67, 115, 11),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              isLoading = true;
                            });
                            if (Email.text.isNotEmpty &&
                                AccessKey.text.isNotEmpty) {
                              try {
                                await FirebaseAuth.instance
                                    .signInWithEmailAndPassword(
                                      email: Email.text.trim(),
                                      password: AccessKey.text.trim(),
                                    );
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const HomePage(),
                                  ),
                                );
                              } on FirebaseAuthException catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.message ?? "An error occurred",
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                setState(() {
                                  isLoading = false;
                                });
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "An unexpected error occurred",
                                    ),
                                  ),
                                );
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please fill in all fields"),
                                ),
                              );
                              setState(() {
                                isLoading = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading == true
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : const Text(
                                  "SIGN IN",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 40),
                    //   child: SizedBox(
                    //     width: double.infinity,
                    //     child: Container(
                    //       padding: const EdgeInsets.all(3),
                    //       decoration: BoxDecoration(
                    //         gradient: const LinearGradient(
                    //           colors: [
                    //             Color.fromARGB(255, 103, 214, 106),
                    //             Color.fromARGB(255, 67, 115, 11),
                    //           ],
                    //         ),
                    //         borderRadius: BorderRadius.circular(100),
                    //       ),
                    //       child: SizedBox(
                    //         height: 52,
                    //         child: ElevatedButton(
                    //           onPressed: () async {

                    //           },
                    //           style: ElevatedButton.styleFrom(
                    //             backgroundColor: Colors.transparent,
                    //             shadowColor: Colors.transparent,
                    //             shape: RoundedRectangleBorder(
                    //               borderRadius: BorderRadius.circular(100),
                    //             ),
                    //           ),
                    //           child: Row(
                    //             mainAxisAlignment: MainAxisAlignment.center,
                    //             children: [
                    //               Container(
                    //                 width: 28,
                    //                 height: 28,
                    //                 padding: const EdgeInsets.all(4),
                    //                 decoration: BoxDecoration(
                    //                   color: Colors.transparent,
                    //                   borderRadius: BorderRadius.circular(6),
                    //                 ),
                    //                 child: Image.network(
                    //                   "https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png",
                    //                   fit: BoxFit.contain,
                    //                   errorBuilder: (context, error, stackTrace) {
                    //                     return const Icon(
                    //                       Icons.g_mobiledata,
                    //                       color: Colors.black,
                    //                       size: 20,
                    //                     );
                    //                   },
                    //                 ),
                    //               ),
                    //               SizedBox(width: 12),
                    //               Text(
                    //                 "CONTINUE WITH GOOGLE",
                    //                 style: TextStyle(
                    //                   color: Colors.white,
                    //                   fontSize: 18,
                    //                   fontWeight: FontWeight.bold,
                    //                 ),
                    //               ),
                    //             ],
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
