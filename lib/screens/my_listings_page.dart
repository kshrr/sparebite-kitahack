import 'dart:convert'; // ⭐ REQUIRED for base64
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyListingsPage extends StatelessWidget {
  const MyListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Listings"),
        centerTitle: true,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("food_listings")
            .where("donorId", isEqualTo: uid)
            .orderBy("createdAt", descending: true)
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No listings yet.\nStart donating food!",
                textAlign: TextAlign.center,
              ),
            );
          }

          final listings = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: listings.length,
            itemBuilder: (_, index) {
              final data = listings[index].data() as Map<String, dynamic>;
              return ListingCard(data: data);
            },
          );
        },
      ),
    );
  }
}

class ListingCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const ListingCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final expiryTime = data["expiryTime"] != null
        ? (data["expiryTime"] as Timestamp).toDate()
        : null;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [

            // ---------- FOOD IMAGE ----------
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: data["imageBase64"] != null
                  ? Image.memory(
                      base64Decode(data["imageBase64"]),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.fastfood, size: 60),
            ),

            const SizedBox(width: 14), // ⭐ spacing fix

            // ---------- DETAILS ----------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    data["foodName"] ?? "Unknown Food",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text("Quantity: ${data["quantity"] ?? "-"}"),
                  Text("Category: ${data["category"] ?? "-"}"),
                  Text("Location: ${data["location"] ?? "-"}"),

                  if (expiryTime != null)
                    Text(
                      "Expires: ${formatDate(expiryTime)}",
                      style: const TextStyle(color: Colors.red),
                    ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: getStatusColor(data["status"]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data["status"] ?? "pending",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- FORMAT DATE ----------
String formatDate(DateTime date) {
  return "${date.year}-${date.month}-${date.day} "
      "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
}

// ---------- STATUS COLOR ----------
Color getStatusColor(String? status) {
  switch (status) {
    case "pending":
      return Colors.orange;
    case "assigned":
      return Colors.blue;
    case "completed":
      return Colors.green;
    default:
      return Colors.grey;
  }
}
