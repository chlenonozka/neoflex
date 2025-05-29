import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_info_model.dart';

class CompanyInfoRepository {
  final CollectionReference _companyInfoCollection =
      FirebaseFirestore.instance.collection('company_info');

  Future<List<CompanyInfo>> getCompanyInfo() async {
    final querySnapshot = await _companyInfoCollection.orderBy('order').get();
    return querySnapshot.docs
        .map((doc) => CompanyInfo.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> addCompanyInfo(CompanyInfo info) async {
    await _companyInfoCollection.add(info.toMap());
  }

  Future<void> updateCompanyInfo(CompanyInfo info) async {
    await _companyInfoCollection.doc(info.id).update(info.toMap());
  }

  Future<void> deleteCompanyInfo(String id) async {
    await _companyInfoCollection.doc(id).delete();
  }
}