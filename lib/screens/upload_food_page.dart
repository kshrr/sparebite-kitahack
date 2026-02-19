import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UploadFoodPage extends StatefulWidget {
  const UploadFoodPage({super.key});

  @override
  State<UploadFoodPage> createState() => _UploadFoodPageState();
}

class _UploadFoodPageState extends State<UploadFoodPage> {
  final _formKey = GlobalKey<FormState>();

  final foodNameController = TextEditingController();
  final quantityController = TextEditingController();
  final locationController = TextEditingController();

  String category = "Prepared Meals";
  DateTime? expiryTime;

  Future<void> pickExpiryTime() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => expiryTime = picked);
    }
  }

  void submitForm() async {
  if (_formKey.currentState!.validate()) {
    try {
      await FirebaseFirestore.instance
          .collection("food_listings")
          .add({
        "foodName": foodNameController.text,
        "quantity": quantityController.text,
        "category": category,
        "location": locationController.text,
        "expiryTime": expiryTime,
        "status": "pending",
        "createdAt": Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food uploaded successfully")),
      );

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Surplus Food")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              /// Food Name
              TextFormField(
                controller: foodNameController,
                decoration: const InputDecoration(
                  labelText: "Food Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Enter food name" : null,
              ),

              const SizedBox(height: 15),

              /// Quantity
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: "Quantity (e.g. 25 meals)",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Enter quantity" : null,
              ),

              const SizedBox(height: 15),

              /// Category Dropdown
              DropdownButtonFormField(
                value: category,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Prepared Meals",
                    child: Text("Prepared Meals"),
                  ),
                  DropdownMenuItem(
                    value: "Baked Goods",
                    child: Text("Baked Goods"),
                  ),
                  DropdownMenuItem(
                    value: "Fresh Produce",
                    child: Text("Fresh Produce"),
                  ),
                ],
                onChanged: (value) {
                  setState(() => category = value!);
                },
              ),

              const SizedBox(height: 15),

              /// Expiry Time Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Expiry Date"),
                subtitle: Text(
                  expiryTime == null
                      ? "Select expiry date"
                      : expiryTime.toString().split(" ")[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: pickExpiryTime,
              ),

              const SizedBox(height: 15),

              /// Pickup Location
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: "Pickup Location",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Enter location" : null,
              ),

              const SizedBox(height: 20),

              /// Upload Image Button (UI only)
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.image),
                label: const Text("Upload Food Image"),
              ),

              const SizedBox(height: 30),

              /// Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text("Create Listing"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
