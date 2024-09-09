import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:golbang/models/hole_score.dart';
import 'package:golbang/pages/game/overall_score_page.dart';

import '../../models/socket/score_card.dart';

class ScoreCardPage extends StatefulWidget {
  final int participant_id;

  const ScoreCardPage({super.key, required this.participant_id});
  @override
  _ScoreCardPageState createState() => _ScoreCardPageState();
}

class _ScoreCardPageState extends State<ScoreCardPage> {
  int _currentPageIndex = 0;
  late final WebSocketChannel _channel;

  final List<ScoreCard> _teamMembers = []; // ScoreCard 리스트
  final Map<int, List<HoleScore>> _scorecard = {}; // 참가자별 홀 점수

  @override
  void initState() {
    super.initState();

    // WebSocket 연결 설정
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://${dotenv.env['API_HOST']}/participants/${widget.participant_id}/group/stroke'), // 실제 WebSocket 서버 주소로 변경
    );

    // WebSocket 메시지를 수신
    _channel.stream.listen((data) {
      _handleWebSocketData(data);
    });
  }

  @override
  void dispose() {
    _channel.sink.close(); // WebSocket 연결 종료
    super.dispose();
  }

  void _handleWebSocketData(String data) {
    // WebSocket에서 수신한 JSON 데이터를 파싱하여 ScoreCard 갱신
    List<dynamic> parsedData = jsonDecode(data);

    for (var entry in parsedData) {
      int participantId = int.parse(entry['participant_id']);
      String userName = entry['user_name'] ?? 'Unknown';
      int groupType = int.parse(entry['group_type']);
      String teamType = entry['team_type'];
      bool isGroupWin = entry['is_group_win'];
      bool isGroupWinHandicap = entry['is_group_win_handicap'];
      int sumScore = entry['sum_score'] ?? 0;
      int handicapScore = entry['handicap_score'] ?? 0;
      List<dynamic> scoresJson = entry['scores'];

      // 홀 점수 데이터를 HoleScore 리스트로 변환
      List<HoleScore> scores = scoresJson.map((scoreData) {
        return HoleScore(
          holeNumber: scoreData['hole_number'],
          score: scoreData['score'],
        );
      }).toList();

      // ScoreCard 생성
      ScoreCard scoreCard = ScoreCard(
        participantId: participantId,
        userName: userName,
        teamType: teamType,
        groupType: groupType,
        isGroupWin: isGroupWin,
        isGroupWinHandicap: isGroupWinHandicap,
        sumScore: sumScore,
        handicapScore: handicapScore,
        scores: scores,
      );

      // 기존 팀원 정보 갱신 또는 새로운 팀원 추가
      setState(() {
        int existingIndex =
        _teamMembers.indexWhere((sc) => sc.participantId == participantId);

        if (existingIndex != -1) {
          _teamMembers[existingIndex] = scoreCard;
        } else {
          _teamMembers.add(scoreCard);
        }

        _scorecard[participantId] = scores;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('제 18회 iNES 골프대전', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    onPageChanged: (index) {
                      setState(() {
                        _currentPageIndex = index;
                      });
                    },
                    children: [
                      _buildScoreTable(1, 9),
                      _buildScoreTable(10, 18),
                    ],
                  ),
                ),
                _buildPageIndicator(),
              ],
            ),
          ),
          SizedBox(height: 8),
          _buildSummaryTable(),
        ],
      ),
      backgroundColor: Colors.black,
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/google.png',
                height: 40,
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '제 18회 iNES 골프대전',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2024.03.18',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OverallScorePage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                  ),
                  child: Text('전체 현황 조회'),
                ),
              ),
              SizedBox(width: 8),
              _buildRankIndicator('Rank', '2 고동범', Colors.red),
              SizedBox(width: 8),
              _buildRankIndicator('Handicap', '3 고동범', Colors.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankIndicator(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTable(int startHole, int endHole) {
    return SingleChildScrollView(
      child: Container(
        color: Colors.black,
        padding: EdgeInsets.all(16.0),
        child: Table(
          border: TableBorder.all(color: Colors.grey),
          children: [
            _buildTableHeaderRow(),
            for (int i = startHole; i <= endHole; i++) _buildEditableTableRow(i - 1),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeaderRow() {
    return TableRow(
      children: [
        _buildTableHeaderCell('홀'),
        for (ScoreCard member in _teamMembers) _buildTableHeaderCell(member.userName ?? 'Unknown'),
        _buildTableHeaderCell('니어/롱기'),
      ],
    );
  }

  Widget _buildTableHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
      child: Center(
        child: Text(
          title,
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  TableRow _buildEditableTableRow(int holeIndex) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              (holeIndex + 1).toString(),
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        for (ScoreCard member in _teamMembers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
            child: Center(
              child: Text(
                _scorecard[member.participantId]![holeIndex].score.toString(),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
          child: Center(
            child: TextFormField(
              initialValue: '', // 니어/롱기 정보
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                // 니어/롱기 정보 업데이트 처리
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4.0),
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTable() {
    return Container(); // 요약 테이블 구현
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIndicatorDot(0),
          SizedBox(width: 8),
          _buildIndicatorDot(1),
        ],
      ),
    );
  }

  Widget _buildIndicatorDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPageIndex == index ? Colors.white : Colors.grey,
      ),
    );
  }
}
