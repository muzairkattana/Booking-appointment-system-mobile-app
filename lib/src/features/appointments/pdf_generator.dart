import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';

Future<Uint8List> generatePatientReportPdf(Appointment appointment) async {
  final doc = pw.Document();

  // Load logo and digital stamp from assets
  Uint8List? logoBytes;
  Uint8List? stampBytes;
  try {
    logoBytes = (await rootBundle.load('assets/ChatGPT Image Jul 9, 2025, 11_09_56 PM.png')).buffer.asUint8List();
  } catch (_) {
    try {
      logoBytes = (await rootBundle.load('assets/dr-bashir-photo.jpeg')).buffer.asUint8List();
    } catch (_) {}
  }

  try {
    stampBytes = (await rootBundle.load('assets/DIGITAL_STAMP.png')).buffer.asUint8List();
  } catch (_) {}

  final clinicName = 'GONSTEAD CHIROPRACTIC TREATMENT';
  final clinicAddress = 'Tehsil Road, Near Peshawar Model School, Nowshera City, KPK.';
  final clinicDoctor = 'DR. BASHIR AHMAD';
  final clinicPhone = '+92 304 6996267';
  
  final primaryColor = PdfColor.fromHex('#4C958D');
  final secondaryColor = PdfColor.fromHex('#0F172A');
  final accentColor = PdfColor.fromHex('#F8FAFC');
  final borderColor = PdfColor.fromHex('#E2E8F0');
  final textColor = PdfColor.fromHex('#1E293B');
  final labelColor = PdfColor.fromHex('#64748B');

  final formattedDate = appointment.scheduledAt != null
      ? DateFormat('EEEE, MMMM dd, yyyy').format(appointment.scheduledAt!.toLocal())
      : appointment.time;
  final formattedTime = appointment.scheduledAt != null
      ? DateFormat('hh:mm a').format(appointment.scheduledAt!.toLocal())
      : 'N/A';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Clinic Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoBytes != null)
                      pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          image: pw.DecorationImage(
                            image: pw.MemoryImage(logoBytes),
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          shape: pw.BoxShape.circle,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'GCT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    pw.SizedBox(width: 14),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _cleanText(clinicName),
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _cleanText('Specialized Spine & Posture Care'),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontStyle: pw.FontStyle.italic,
                            color: labelColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _cleanText(clinicAddress),
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _cleanText(clinicDoctor),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      _cleanText('Chiropractic Specialist'),
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: labelColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _cleanText('Mob: $clinicPhone'),
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(height: 1, thickness: 1, color: borderColor),
            pw.SizedBox(height: 18),

            // Report Title Card
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CLINICAL HEALTH REPORT',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    _cleanText('ID: ${appointment.id.toUpperCase()}'),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor(1.0, 1.0, 1.0, 0.8),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Patient & Appointment Grid Layout
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Patient Details Column
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PATIENT INFORMATION',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Name', appointment.patientName, labelColor, textColor),
                        _buildDetailRow('Phone', appointment.phoneNumber.isNotEmpty ? appointment.phoneNumber : 'N/A', labelColor, textColor),
                        _buildDetailRow('Email', appointment.email.isNotEmpty ? appointment.email : 'N/A', labelColor, textColor),
                        _buildDetailRow('Profession', appointment.patientProfession.isNotEmpty ? appointment.patientProfession : 'N/A', labelColor, textColor),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                // Visit Details Column
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VISIT INFORMATION',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _buildDetailRow('Date', formattedDate, labelColor, textColor),
                        _buildDetailRow('Time', formattedTime, labelColor, textColor),
                        _buildDetailRow('Treatment', appointment.treatmentType, labelColor, textColor),
                        _buildDetailRow('Priority', appointment.isEmergency ? 'EMERGENCY' : 'Standard', labelColor, appointment.isEmergency ? PdfColor.fromHex('#EF4444') : textColor, isBoldValue: appointment.isEmergency),
                        _buildDetailRow('Status', appointment.status, labelColor, appointment.status.toLowerCase() == 'confirmed' ? PdfColor.fromHex('#10B981') : textColor, isBoldValue: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // Visit Reason Card (Callout box design)
            if (appointment.visitReason.isNotEmpty) ...[
              pw.Text(
                'Reason for Visit',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: secondaryColor,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EBF7F5'),
                  border: pw.Border(
                    left: pw.BorderSide(color: primaryColor, width: 4),
                  ),
                ),
                child: pw.Text(
                  _cleanText(appointment.visitReason),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: textColor,
                    lineSpacing: 3,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // Clinical notes (Callout box design)
            pw.Text(
              'Clinical Notes & Findings',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: secondaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColor(240 / 255, 253 / 255, 244 / 255),
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColor(16 / 255, 185 / 255, 129 / 255), width: 4),
                ),
              ),
              child: pw.Text(
                _cleanText(appointment.patientNote.isNotEmpty
                    ? appointment.patientNote
                    : 'No clinical notes recorded for this visit.'),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: textColor,
                  lineSpacing: 4,
                ),
              ),
            ),
            pw.SizedBox(height: 16),

            // Cancellation Reason Card (if applicable)
            if (appointment.status.toLowerCase() == 'cancelled' && appointment.cancellationReason.isNotEmpty) ...[
              pw.Text(
                'Cancellation Reason',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#991B1B'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColor(254 / 255, 242 / 255, 242 / 255),
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColor(239 / 255, 68 / 255, 68 / 255), width: 4),
                  ),
                ),
                child: pw.Text(
                  _cleanText(appointment.cancellationReason),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#991B1B'),
                    lineSpacing: 3,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            pw.Spacer(),

            // Signature & Sign-off
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Attending Practitioner',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                    pw.SizedBox(height: 32),
                    pw.Container(
                      width: 140,
                      height: 1,
                      color: const PdfColor(100 / 255, 116 / 255, 139 / 255, 0.5),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _cleanText(clinicDoctor),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    pw.Text(
                      _cleanText('Chiropractic Specialist'),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
                if (stampBytes != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 170,
                        height: 170,
                        child: pw.Image(pw.MemoryImage(stampBytes)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _cleanText('Digitally Verified Report'),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#10B981'),
                        ),
                      ),
                      pw.Text(
                        _cleanText('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now().toLocal())}'),
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: labelColor,
                        ),
                      ),
                    ],
                  )
                else
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        _cleanText('Document Verified'),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#10B981'),
                        ),
                      ),
                      pw.SizedBox(height: 32),
                      pw.Text(
                        _cleanText('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now().toLocal())}'),
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(height: 1, thickness: 0.5, color: borderColor),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'This report is generated digitally and verified with a digital doctor stamp. All information is confidential.',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: const PdfColor(100 / 255, 116 / 255, 139 / 255, 0.7),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _buildDetailRow(String label, String value, PdfColor labelColor, PdfColor valueColor, {bool isBoldValue = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 60,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: labelColor,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor,
            ),
          ),
        ),
      ],
    ),
  );
}

String _cleanText(String text) {
  return text
      .replaceAll('•', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('”', '"')
      .replaceAll('“', '"')
      .runes
      .map((r) => (r >= 32 && r <= 126) || r == 10 || r == 13 ? String.fromCharCode(r) : '')
      .join('');
}
