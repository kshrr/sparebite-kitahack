import 'dart:io';
import 'dart:convert'; 

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadFoodPage extends StatefulWidget {
  const UploadFoodPage({super.key});

  @override
  State<UploadFoodPage> createState() => _UploadFoodPageState();
}

class _UploadFoodPageState extends State<UploadFoodPage> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final locationController = TextEditingController();

  File? imageFile;
  Uint8List? webImage;

  bool isLoading = false;

  String selectedCategory = "Meals";
  DateTime? expiryTime;

  final picker = ImagePicker();
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // ================= PICK IMAGE =================
  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() => webImage = bytes);
    } else {
      setState(() => imageFile = File(picked.path));
    }
  }

  // ================= PICK EXPIRY TIME =================
  Future<void> pickExpiryTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      expiryTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  // ================= UPLOAD FOOD =================
Future<void> uploadFood() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showError("Please login first");
      return;
    }

    if (nameController.text.trim().isEmpty ||
        quantityController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        expiryTime == null ||
        (imageFile == null && webImage == null)) {
      showError("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    final uid = user.uid;

    // ---------- CONVERT IMAGE TO BASE64 ----------
    String base64Image;

    if (kIsWeb) {
      base64Image = base64Encode(webImage!);
    } else {
      final bytes = await imageFile!.readAsBytes();
      base64Image = base64Encode(bytes);
    }

    print("Image converted to base64");

    // ---------- SAVE TO FIRESTORE ----------
    await FirebaseFirestore.instance.collection("food_listings").add({
      "foodName": nameController.text.trim(),
      "quantity": quantityController.text.trim(),
      "category": selectedCategory,
      "location": locationController.text.trim(),
      "expiryTime": Timestamp.fromDate(expiryTime!),
      "createdAt": Timestamp.now(),
      "imageBase64": base64Image, // NEW FIELD
      "donorId": uid,
      "status": "pending",
    });

    if (!mounted) return;

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Food uploaded successfully")),
    );

    Navigator.pop(context);

  } catch (e) {
    if (!mounted) return;
    setState(() => isLoading = false);
    showError("Upload failed: $e");
  }
}


  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Donate Food")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // IMAGE PICKER
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: (imageFile == null && webImage == null)
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40),
                          SizedBox(height: 8),
                          Text("Tap to upload image"),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.memory(webImage!, fit: BoxFit.cover)
                            : Image.file(imageFile!, fit: BoxFit.cover),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // FOOD NAME
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Food Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // QUANTITY
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // CATEGORY
            DropdownButtonFormField(
              value: selectedCategory,
              items: const [
                DropdownMenuItem(value: "Meals", child: Text("Meals")),
                DropdownMenuItem(
                  value: "Baked Goods",
                  child: Text("Baked Goods"),
                ),
                DropdownMenuItem(value: "Groceries", child: Text("Groceries")),
                DropdownMenuItem(value: "Others", child: Text("Others")),
              ],
              onChanged: (value) {
                setState(() => selectedCategory = value.toString());
              },
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // LOCATION
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: "Pickup Location",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // EXPIRY TIME
            ListTile(
              title: Text(
                expiryTime == null
                    ? "Select Expiry Time"
                    : expiryTime.toString(),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickExpiryTime,
            ),

            const SizedBox(height: 24),

            // SUBMIT
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : uploadFood,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Post Food"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    locationController.dispose();
    super.dispose();
  }
}
