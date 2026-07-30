import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _numFmt = NumberFormat('#,###', 'ko_KR');

String fmtNum(int n) => _numFmt.format(n);
String fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String monthStart() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
}
String today() => fmtDate(DateTime.now());

Color typeColor(String type) {
  switch (type) {
    case '과세': return const Color(0xFF0D6EFD);
    case '영세': return const Color(0xFF198754);
    default:    return const Color(0xFF6C757D);
  }
}

Color issueColor(String issueType) {
  switch (issueType) {
    case '전자': return const Color(0xFF0D6EFD);
    case '종이': return const Color(0xFF6C757D);
    default:    return const Color(0xFFFFC107);
  }
}

Color issueTextColor(String issueType) =>
    issueType == '미발행' ? Colors.black87 : Colors.white;

Widget typeBadge(String type) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(color: typeColor(type), borderRadius: BorderRadius.circular(4)),
  child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 11)),
);

Widget issueBadge(String issueType) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(color: issueColor(issueType), borderRadius: BorderRadius.circular(4)),
  child: Text(issueType,
    style: TextStyle(color: issueTextColor(issueType), fontSize: 11)),
);
