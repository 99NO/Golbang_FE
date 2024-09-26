import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/create_event.dart';
import '../../models/create_participant.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';
import 'event_service_provider.dart';
import 'event_state_provider.dart';

// EventStateNotifierProvider 정의
final eventStateNotifierProvider = StateNotifierProvider<EventStateNotifierProvider, EventState>((ref) {
  final eventService = ref.read(eventServiceProvider);
  return EventStateNotifierProvider(eventService);
});

class EventStateNotifierProvider extends StateNotifier<EventState> {
  final EventService _eventService;

  EventStateNotifierProvider(this._eventService) : super(EventState());

  // 이벤트 목록을 불러오는 함수
  Future<void> fetchEvents() async {
    try {
      final List<Event> events = await _eventService.getEventsForMonth();
      state = state.copyWith(eventList: events);
    } catch (e) {
      state = state.copyWith(errorMessage: '이벤트 목록을 불러오는 중 오류 발생');
    }
  }

  // 이벤트 생성
  Future<bool> createEvent(CreateEvent event, List<CreateParticipant> participants, String clubId) async {
    try {
      final success = await _eventService.postEvent(clubId: int.parse(clubId), event: event, participants: participants);
      if (success) {
        await fetchEvents();
        return true; // 성공 시 true 반환
      } else {
        state = state.copyWith(errorMessage: '이벤트 생성 실패');
        return false; // 실패 시 false 반환
      }
    } catch (e) {
      state = state.copyWith(errorMessage: '이벤트 생성 중 오류 발생');
      return false; // 오류 발생 시 false 반환
    }
  }




  // 이벤트 수정
  Future<void> updateEvent(CreateEvent updatedEvent, List<CreateParticipant> participants) async {
    try {
      final success = await _eventService.updateEvent(event: updatedEvent, participants: participants);
      if (success) {
        final updatedList = state.eventList.map((event) {
          // updatedEvent를 Event로 변환하여 업데이트
          return event.eventId == updatedEvent.eventId ? _convertToEvent(updatedEvent) : event;
        }).toList();
        state = state.copyWith(eventList: updatedList);
      } else {
        state = state.copyWith(errorMessage: '이벤트 수정 실패');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: '이벤트 수정 중 오류 발생');
    }
  }

// CreateEvent를 Event로 변환하는 함수 추가
  Event _convertToEvent(CreateEvent createEvent) {
    return Event(
      eventId: createEvent.eventId!,
      memberGroup: int.parse(createEvent.memberGroup ?? '0'),
      eventTitle: createEvent.eventTitle,
      location: createEvent.location,
      startDateTime: createEvent.startDateTime,
      endDateTime: createEvent.endDateTime,
      repeatType: createEvent.repeatType,
      gameMode: createEvent.gameMode,
      alertDateTime: createEvent.alertDateTime,
      participantsCount: 0,  // 추가 정보 필요 시 변경
      partyCount: 0,
      acceptCount: 0,
      denyCount: 0,
      pendingCount: 0,
      myParticipantId: 0,
      participants: [], // 추가 정보 필요 시 변경
    );
  }

  // 이벤트 삭제
  Future<void> deleteEvent(int eventId) async {
    try {
      final success = await _eventService.deleteEvent(eventId);
      if (success) {
        state = state.copyWith(
          eventList: state.eventList.where((event) => event.eventId != eventId).toList(),
        );
      } else {
        state = state.copyWith(errorMessage: '이벤트 삭제 실패');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: '이벤트 삭제 중 오류 발생');
    }
  }

  // 상태 초기화
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
