import 'package:flutter/material.dart';

/// What is being scanned. Each type picks its own look, layout and size, like a pro scanner app:
/// an ID card comes out front + back at real size on one A4 sheet, a book is cut into single pages
/// without the binding shadow, a receipt keeps its long narrow shape, a whiteboard gets even light.
class ScanType {
  final String id;
  /// English label (translated with tr()).
  final String label;
  final IconData icon;
  /// 'original' | 'natural' | 'bright' | 'bw'
  final String filter;
  /// 'normal' | 'book' | 'card' | 'receipt' | 'board' | 'photo'
  final String layout;
  /// Cards: real size in millimetres and how many sides (front, back).
  final double cardW, cardH;
  final int sides;
  /// Notes and handwriting: even out the light.
  final bool flatten;
  /// The group shown in the picker.
  final String group;
  const ScanType(this.id, this.label, this.icon, this.filter, this.layout, this.group,
      {this.cardW = 0, this.cardH = 0, this.sides = 1, this.flatten = false});

  bool get isCard => layout == 'card';
}

/// ID-1 is the size of bank cards, ID cards and driving licences (ISO/IEC 7810).
const _id1W = 85.6, _id1H = 53.98;

const List<ScanType> scanTypes = [
  ScanType('document', 'Document', Icons.description_rounded, 'natural', 'normal', 'Papers'),
  ScanType('book', 'Book', Icons.menu_book_rounded, 'natural', 'book', 'Papers'),
  ScanType('idcard', 'ID card', Icons.badge_rounded, 'natural', 'card', 'Cards', cardW: _id1W, cardH: _id1H, sides: 2),
  ScanType('passport', 'Passport', Icons.public_rounded, 'natural', 'card', 'Cards', cardW: 125, cardH: 88),
  ScanType('licence', 'Driving licence', Icons.directions_car_rounded, 'natural', 'card', 'Cards', cardW: _id1W, cardH: _id1H, sides: 2),
  ScanType('permit', 'Residence permit', Icons.home_work_rounded, 'natural', 'card', 'Cards', cardW: _id1W, cardH: _id1H, sides: 2),
  ScanType('health', 'Health card', Icons.health_and_safety_rounded, 'natural', 'card', 'Cards', cardW: _id1W, cardH: _id1H, sides: 2),
  ScanType('student', 'Student card', Icons.school_rounded, 'natural', 'card', 'Cards', cardW: _id1W, cardH: _id1H, sides: 2),
  ScanType('business', 'Business card', Icons.contact_mail_rounded, 'bright', 'card', 'Cards', cardW: 85, cardH: 55, sides: 2),
  ScanType('receipt', 'Receipt', Icons.receipt_long_rounded, 'bright', 'receipt', 'Money'),
  ScanType('invoice', 'Invoice', Icons.request_quote_rounded, 'bright', 'normal', 'Money'),
  ScanType('statement', 'Bank statement', Icons.account_balance_rounded, 'bw', 'normal', 'Money'),
  ScanType('contract', 'Contract', Icons.gavel_rounded, 'bw', 'normal', 'Papers'),
  ScanType('form', 'Form', Icons.assignment_rounded, 'bw', 'normal', 'Papers'),
  ScanType('letter', 'Letter', Icons.mail_rounded, 'natural', 'normal', 'Papers'),
  ScanType('prescription', 'Prescription', Icons.medication_rounded, 'bright', 'normal', 'Papers'),
  ScanType('diploma', 'Diploma', Icons.workspace_premium_rounded, 'natural', 'normal', 'Papers'),
  ScanType('whiteboard', 'Whiteboard', Icons.dashboard_rounded, 'bright', 'board', 'Boards'),
  ScanType('blackboard', 'Blackboard', Icons.border_color_rounded, 'original', 'board', 'Boards'),
  ScanType('notes', 'Handwritten notes', Icons.edit_note_rounded, 'natural', 'normal', 'Boards', flatten: true),
  ScanType('postit', 'Sticky notes', Icons.sticky_note_2_rounded, 'bright', 'normal', 'Boards'),
  ScanType('magazine', 'Magazine', Icons.auto_stories_rounded, 'natural', 'book', 'Reading'),
  ScanType('newspaper', 'Newspaper', Icons.newspaper_rounded, 'bw', 'normal', 'Reading'),
  ScanType('score', 'Sheet music', Icons.music_note_rounded, 'bw', 'book', 'Reading'),
  ScanType('recipe', 'Recipe', Icons.restaurant_menu_rounded, 'natural', 'normal', 'Reading'),
  ScanType('map', 'Map or plan', Icons.map_rounded, 'natural', 'normal', 'Reading'),
  ScanType('photo', 'Photo', Icons.photo_rounded, 'original', 'photo', 'Pictures'),
  ScanType('drawing', 'Drawing', Icons.brush_rounded, 'original', 'photo', 'Pictures'),
];

ScanType scanTypeById(String id) => scanTypes.firstWhere((t) => t.id == id, orElse: () => scanTypes.first);
