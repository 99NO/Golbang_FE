import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golbang/models/event.dart';
import 'package:golbang/services/event_service.dart';
import 'package:excel/excel.dart' as xx; // excel 패키지 추가
import 'package:path_provider/path_provider.dart';  // path_provider 패키지 임포트
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart'; // 이메일 전송 패키지 추가
import '../../repoisitory/secure_storage.dart'; // Riverpod 관련 패키지

class EventResultFullScoreCard extends ConsumerStatefulWidget {
  final int eventId;

  EventResultFullScoreCard({required this.eventId});

  @override
  _EventResultFullScoreCardState createState() => _EventResultFullScoreCardState();
}

class _EventResultFullScoreCardState extends ConsumerState<EventResultFullScoreCard> {
  List<dynamic> participants = [];
  Map<String, dynamic>? teamAScores;
  Map<String, dynamic>? teamBScores;
  bool isLoading = true;
  Event? eventDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchScores();
    });
  }

  Future<void> fetchScores() async {
    final storage = ref.watch(secureStorageProvider);
    final eventService = EventService(storage);

    try {
      final response = await eventService.getScoreData(widget.eventId);
      final temp_eventDetail = await eventService.getEventDetails(widget.eventId);
      if (response != null) {
        setState(() {
          participants = response['participants'];
          teamAScores = response['team_a_scores'];
          teamBScores = response['team_b_scores'];
          isLoading = false;
          eventDetail = temp_eventDetail;
        });
      } else {
        print('Failed to load scores: response is null');
      }
    } catch (error) {
      print('Error fetching scores: $error');
    }
  }
  Future<void> exportAndSendEmail() async {
    // 엑셀 파일 생성
    var excel = xx.Excel.createExcel();
    var sheet = excel['Sheet1'];

    // 열 제목 설정 (기본은 행 형태로)
    List<String> columnTitles = [
      '팀',
      '참가자',
      '전반전',
      '후반전',
      '전체 스코어',
      '핸디캡 스코어',
      'hole 1',
      'hole 2',
      'hole 3',
      'hole 4',
      'hole 5',
      'hole 6',
      'hole 7',
      'hole 8',
      'hole 9',
      'hole 10',
      'hole 11',
      'hole 12',
      'hole 13',
      'hole 14',
      'hole 15',
      'hole 16',
      'hole 17',
      'hole 18'
    ];

    // 팀 데이터와 참가자별 점수를 병합하여 정렬
    List<Map<String, dynamic>> sortedParticipants = [
      if (teamAScores != null)
        {
          'team': 'Team A',
          'participant_name': '-',
          'front_nine_score': teamAScores?['front_nine_score'],
          'back_nine_score': teamAScores?['back_nine_score'],
          'total_score': teamAScores?['total_score'],
          'handicap_score': '-',
          'scorecard': List.filled(18, '-'),
        },
      if (teamBScores != null)
        {
          'team': 'Team B',
          'participant_name': '-',
          'front_nine_score': teamBScores?['front_nine_score'],
          'back_nine_score': teamBScores?['back_nine_score'],
          'total_score': teamBScores?['total_score'],
          'handicap_score': '-',
          'scorecard': List.filled(18, '-'),
        },
      ...participants.map((participant) => {
        'team': participant['team'], // 팀 정보 추가
        'participant_name': participant['participant_name'],
        'front_nine_score': participant['front_nine_score'],
        'back_nine_score': participant['back_nine_score'],
        'total_score': participant['total_score'],
        'handicap_score': participant['handicap_score'],
        'scorecard': participant['scorecard'],
      }),
    ];

    // 팀 기준으로 정렬
    sortedParticipants.sort((a, b) => a['team'].compareTo(b['team']));

    // 데이터를 행 기준으로 변환
    List<List<dynamic>> rows = [
      columnTitles, // 제목
      ...sortedParticipants.map((participant) {
        return [
          participant['team'],
          participant['participant_name'],
          participant['front_nine_score'],
          participant['back_nine_score'],
          participant['total_score'],
          participant['handicap_score'],
          ...List.generate(18, (i) => participant['scorecard'].length > i ? participant['scorecard'][i] : '-'),
        ];
      }),
    ];

    // Transpose 적용 (행과 열 교환)
    List<List<dynamic>> transposedData = List.generate(
      rows[0].length,
          (colIndex) => rows.map((row) => row[colIndex]).toList(),
    );

    // 엑셀에 데이터 쓰기
    for (var row in transposedData) {
      sheet.appendRow(row);
    }

    // 외부 저장소 경로 가져오기
    Directory? directory = await getExternalStorageDirectory();
    if (directory != null) {
      String filePath = '${directory.path}/event_scores_${eventDetail?.eventId}.xlsx';
      File file = File(filePath);

      // 파일 쓰기
      await file.writeAsBytes(excel.encode()!);

      // 이메일 전송
      final Email email = Email(
        body: '제목: ${eventDetail?.eventTitle}\n 날짜: ${eventDetail?.startDateTime.toIso8601String().split('T').first}\n 장소: ${eventDetail?.site}',
        subject: '${eventDetail?.club!.name}_${eventDetail?.startDateTime.toIso8601String().split('T').first}_${eventDetail?.eventTitle}',
        recipients: [], // 받을 사람의 이메일 주소
        attachmentPaths: [filePath], // 첨부할 파일 경로
        isHTML: false,
      );

      try {
        await FlutterEmailSender.send(email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이메일이 전송되었습니다.')),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이메일 전송 실패: $error')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 경로를 찾을 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // 배경색 설정
      appBar: AppBar(
        title: Text('스코어카드'),
        actions: [
          IconButton(
            icon: Icon(Icons.email), // 이메일 아이콘으로 변경
            onPressed: exportAndSendEmail,   // 이메일 전송 기능으로 변경
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        scrollDirection: Axis.vertical, // 세로 스크롤
        child: Column(
          children: [
            buildParticipantDataTable(), // 참가자별 홀 점수 테이블
            buildScoreDataTable(), // 팀 점수 테이블
          ],
        ),
      ),
    );
  }

  // 팀 및 참가자 점수를 표시하는 DataTable 위젯
  Widget buildScoreDataTable() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // 가로 스크롤 설정
        child: Card(
          color: Colors.white, // 카드 배경 설정
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('팀/참가자')),
                DataColumn(label: Text('전반전')),
                DataColumn(label: Text('후반전')),
                DataColumn(label: Text('전체 스코어')),
                DataColumn(label: Text('핸디캡 스코어')),
              ],
              rows: [
                if (teamAScores != null) buildTeamDataRow('Team A', teamAScores), // teamAScores가 null이 아니면 표시
                if (teamBScores != null) buildTeamDataRow('Team B', teamBScores), // teamBScores가 null이 아니면 표시
                for (var participant in participants) buildParticipantDataRow(participant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 팀 점수 행을 생성하는 함수
  DataRow buildTeamDataRow(String teamName, Map<String, dynamic>? teamScores) {
    return DataRow(
      cells: [
        DataCell(Text(teamName)),
        DataCell(Text('${teamScores?['front_nine_score'] ?? ''}')),
        DataCell(Text('${teamScores?['back_nine_score'] ?? ''}')),
        DataCell(Text('${teamScores?['total_score'] ?? ''}')),
        DataCell(Text('${teamScores?['handicap_score'] ?? ''}')),
      ],
    );
  }

  // 참가자 점수 행을 생성하는 함수
  DataRow buildParticipantDataRow(Map<String, dynamic> participant) {
    return DataRow(
      cells: [
        DataCell(Text(participant['participant_name'] ?? '')),
        DataCell(Text('${participant['front_nine_score']}')),
        DataCell(Text('${participant['back_nine_score']}')),
        DataCell(Text('${participant['total_score']}')),
        DataCell(Text('${participant['handicap_score']}')),
      ],
    );
  }

  // 참가자별 홀 점수를 표시하는 DataTable 위젯
  Widget buildParticipantDataTable() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // 가로 스크롤 설정
        child: Card(
          color: Colors.white, // 카드 배경 설정
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: DataTable(
              columns: [
                const DataColumn(label: Text('홀')),
                for (var participant in participants)
                  DataColumn(label: Text(participant['participant_name'])),
              ],
              rows: [
                for (int hole = 1; hole <= 18; hole++)
                  DataRow(
                    cells: [
                      DataCell(Text(hole.toString())), // 홀 번호
                      for (var participant in participants)
                        DataCell(Text(
                          participant['scorecard'].length >= hole
                              ? participant['scorecard'][hole - 1].toString()
                              : '-',
                        )), // 각 참가자의 홀별 점수
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
