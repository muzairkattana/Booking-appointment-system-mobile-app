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
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(22),
      header: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Top Accent Bar
            pw.Container(
              height: 4,
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
            pw.SizedBox(height: 8),
            // Clinic Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoBytes != null)
                        pw.Container(
                          width: 50,
                          height: 50,
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
                          width: 50,
                          height: 50,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            shape: pw.BoxShape.circle,
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'GCT',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _cleanText(clinicName),
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: secondaryColor,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              _cleanText('Specialized Spine & Posture Care'),
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontStyle: pw.FontStyle.italic,
                                color: labelColor,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _cleanText(clinicAddress),
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                color: labelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _cleanText(clinicDoctor),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      _cleanText('Chiropractic Specialist'),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: labelColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _cleanText('Mob: $clinicPhone'),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(height: 1, thickness: 1, color: borderColor),
            pw.SizedBox(height: 10),
          ],
        );
      },
      footer: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
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
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 120,
                      height: 1,
                      color: const PdfColor(100 / 255, 116 / 255, 139 / 255, 0.5),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _cleanText(clinicDoctor),
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    pw.Text(
                      _cleanText('Chiropractic Specialist'),
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
                if (stampBytes != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 10, right: -10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          width: 80,
                          height: 80,
                          child: pw.Image(pw.MemoryImage(stampBytes)),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _cleanText('Digitally Verified Report'),
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#10B981'),
                          ),
                        ),
                        pw.Text(
                          _cleanText('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now().toLocal())}'),
                          style: pw.TextStyle(
                            fontSize: 6.5,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          _cleanText('Document Verified'),
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#10B981'),
                          ),
                        ),
                        pw.SizedBox(height: 20),
                        pw.Text(
                          _cleanText('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now().toLocal())}'),
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(height: 1, thickness: 0.5, color: borderColor),
            pw.SizedBox(height: 4),
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
      build: (context) {
        return [
          // Report Title Card
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
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
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  _cleanText('ID: ${appointment.id.toUpperCase()}'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor(1.0, 1.0, 1.0, 0.8),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // Patient & Appointment Grid Layout
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Patient Details Column
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
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
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      _buildDetailRow('Name', appointment.patientName, labelColor, textColor),
                      _buildDetailRow('Phone', appointment.phoneNumber.isNotEmpty ? appointment.phoneNumber : 'N/A', labelColor, textColor),
                      _buildDetailRow('Email', appointment.email.isNotEmpty ? appointment.email : 'N/A', labelColor, textColor),
                      _buildDetailRow('Profession', appointment.patientProfession.isNotEmpty ? appointment.patientProfession : 'N/A', labelColor, textColor),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              // Visit Details Column
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
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
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
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
          pw.SizedBox(height: 10),

          // Visit Reason Card
          if (appointment.visitReason.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 10,
                        color: primaryColor,
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'REASON FOR VISIT',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _cleanText(appointment.visitReason),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: textColor,
                      lineSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],

          // Clinical Assessment & Vitals Card
          if ((appointment.painLevel != null) || 
              appointment.bloodPressure.isNotEmpty || 
              (appointment.pulseRate != null) || 
              appointment.adjustedSegments.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 10,
                        color: primaryColor,
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'CLINICAL ASSESSMENT & VITALS',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (appointment.painLevel != null)
                              _buildDetailRow('Pain Scale', '${appointment.painLevel}/10 (VAS)', labelColor, textColor),
                            if (appointment.bloodPressure.isNotEmpty)
                              _buildDetailRow('Blood Pressure', appointment.bloodPressure, labelColor, textColor),
                            if (appointment.pulseRate != null)
                              _buildDetailRow('Pulse Rate', '${appointment.pulseRate} bpm', labelColor, textColor),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (appointment.adjustedSegments.isNotEmpty) ...[
                              pw.Text(
                                'ADJUSTED SEGMENTS',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: labelColor,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                _cleanText(appointment.adjustedSegments),
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ] else
                              pw.Text('No adjustments registered.', style: pw.TextStyle(fontSize: 8, color: labelColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],

          // Clinical notes
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 4,
                      height: 10,
                      color: PdfColor.fromHex('#10B981'),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      'CLINICAL NOTES & FINDINGS',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#10B981'),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _cleanText(appointment.patientNote.isNotEmpty
                      ? appointment.patientNote
                      : 'No clinical notes recorded for this visit.'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: textColor,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Recommendations & Care Plan
          if (appointment.prescribedExercises.isNotEmpty || appointment.nextFollowUp.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0FDFA'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('#99F6E4')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 10,
                        color: PdfColor.fromHex('#0D9488'),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'PRACTITIONER CARE PLAN & RECOMMENDATIONS',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F766E'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  if (appointment.prescribedExercises.isNotEmpty) ...[
                    pw.Text(
                      'Home Exercises & Posture Tips:',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: labelColor),
                    ),
                    pw.Text(
                      _cleanText(appointment.prescribedExercises),
                      style: pw.TextStyle(fontSize: 8.5, color: textColor),
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  if (appointment.nextFollowUp.isNotEmpty) ...[
                    pw.Row(
                      children: [
                        pw.Text(
                          'Recommended Next Follow-up: ',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: labelColor),
                        ),
                        pw.Text(
                          _cleanText(appointment.nextFollowUp),
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0D9488')),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],

          // Cancellation Reason Card
          if (appointment.status.toLowerCase() == 'cancelled' && appointment.cancellationReason.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FEF2F2'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('#FCA5A5')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 10,
                        color: PdfColor.fromHex('#EF4444'),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'CANCELLATION REASON',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#B91C1C'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _cleanText(appointment.cancellationReason),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromHex('#991B1B'),
                      lineSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ];
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
