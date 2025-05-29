import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Контакты Neoflex',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Основные контакты
          const Text(
            'Основные контакты',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('contacts')
                .where('type', isEqualTo: 'contact')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Ошибка загрузки контактов');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final contacts = snapshot.data?.docs.map((doc) {
                return Contact.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              }).toList() ?? [];

              return Column(
                children: contacts.map((contact) => 
                  _buildContactCard(
                    context,
                    contact.title,
                    contact.value,
                    _getIconData(contact.icon),
                  )
                ).toList(),
              );
            },
          ),
          
          const SizedBox(height: 16),
          // Социальные сети
          const Text(
            'Социальные сети и платформы',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('contacts')
                .where('type', isEqualTo: 'social')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Ошибка загрузки соцсетей');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final socials = snapshot.data?.docs.map((doc) {
                return Contact.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              }).toList() ?? [];

              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3,
                children: socials.map((social) => 
                  _buildSocialButton(
                    context, 
                    social.title, 
                    social.value, 
                    _getIconData(social.icon)
                  )
                ).toList(),
              );
            },
          ),
          
          const SizedBox(height: 16),
          // Офисы
          const Text(
            'Офисы компании',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('contacts')
                .where('type', isEqualTo: 'office')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Ошибка загрузки офисов');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final offices = snapshot.data?.docs.map((doc) {
                return Contact.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              }).toList() ?? [];

              return Column(
                children: offices.map((office) => 
                  _buildOfficeCard(
                    context,
                    office.title,
                    office.value,
                  )
                ).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'language': return Icons.language;
      case 'email': return Icons.email;
      case 'phone': return Icons.phone;
      case 'play_circle_fill': return Icons.play_circle_fill;
      case 'article': return Icons.article;
      case 'send': return Icons.send;
      case 'group': return Icons.group;
      case 'work': return Icons.work;
      case 'play_circle_filled': return Icons.play_circle_filled;
      case 'map': return Icons.map;
      default: return Icons.contact_page;
    }
  }

  Widget _buildContactCard(BuildContext context, String title, String url, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(url.replaceAll('mailto:', '').replaceAll('tel:', '')),
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось открыть $url')),
            );
          }
        },
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, String title, String url, IconData icon) {
    return TextButton(
      onPressed: () async {
        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось открыть $url')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${e.toString()}')),
          );
        }
      },
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
    );
  }

  Widget _buildOfficeCard(BuildContext context, String city, String address) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(city, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(address),
        trailing: IconButton(
          icon: const Icon(Icons.map, color: Colors.blue),
          onPressed: () async {
            final encodedAddress = Uri.encodeComponent('$address, $city');
            final uri = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
            );
            final nativeUri = Uri.parse('geo:0,0?q=$encodedAddress');
            
            try {
              if (await canLaunchUrl(nativeUri)) {
                await launchUrl(nativeUri);
              } else if (await canLaunchUrl(uri)) {
                await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Не удалось открыть карты')),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка карт: ${e.toString()}')),
              );
            }
          },
        ),
      ),
    );
  }
}