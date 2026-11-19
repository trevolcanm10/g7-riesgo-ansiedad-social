import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ansiedad_ml_app/core/app_colors.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/domain/entities/apoyo_academico.dart';
import 'package:ansiedad_ml_app/domain/repositories/apoyo_repository.dart';
import 'package:ansiedad_ml_app/data/models/apoyo_academico_model.dart';
import 'package:ansiedad_ml_app/presentation/pages/apoyo/apoyo_home_page.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/apoyo_viewmodel.dart';

final workshop=AcademicResource(id:7,type:'WORKSHOP',title:'Taller de prueba',description:'Actividad académica',
 modality:'REMOTO',startAt:DateTime.utc(2030,1,2,15),capacity:10,availableSeats:4);
class FakeApoyoRepository implements ApoyoRepository {
 bool enrolled=false, conflict=false;
 AcademicPreferences saved=const AcademicPreferences();
 final interactions=<String>[];
 @override Future<AcademicResourcePage> catalog({required int offset,required int limit,String? type,String? courseCode}) async =>
  AcademicResourcePage([workshop],limit,offset,1);
 @override Future<AcademicResource> resource(int id) async=>workshop;
 @override Future<AcademicPreferences> preferences() async=>saved;
 @override Future<AcademicPreferences> savePreferences(AcademicPreferences value) async {saved=value;return value;}
 @override Future<List<AcademicRecommendation>> recommendations({int limit=10}) async =>
  [AcademicRecommendation(workshop,['Coincide con tus intereses','Tiene cupos disponibles'])];
 @override Future<List<WorkshopEnrollment>> enrollments() async=>enrolled
  ? [WorkshopEnrollment(resourceId:7,title:workshop.title,description:workshop.description,status:'ACTIVE')]:[];
 @override Future<void> recordInteraction(int resourceId,String eventType) async { interactions.add(eventType); }
 @override Future<void> enroll(int resourceId) async {
  if(conflict)throw ApiException(statusCode:409,mensaje:'El taller ya no tiene cupos.');
  enrolled=true;
 }
 @override Future<void> cancelEnrollment(int resourceId) async {enrolled=false;}
}
void main(){
 test('modelo acepta recursos sin modalidad',(){
  final resource=AcademicResourceModel.fromJson({'id':9,'type':'MATERIAL','title':'Guía','description':'Recurso de estudio','modality':null});
  expect(resource.modality,isNull);
 });
 test('guarda preferencias completas y devuelve razones sin puntuación porcentual',()async{
  final repo=FakeApoyoRepository(),vm=ApoyoViewModel(repo);
  final prefs=AcademicPreferences(interests:['matemática'],courseCodes:['MAT101'],
   availableSlots:[const AvailabilitySlot(0,'09:00','11:00')],preferredModalities:['REMOTO']);
  expect(await vm.savePreferences(prefs),isTrue);
  expect(repo.saved.interests,prefs.interests);
  expect(repo.saved.courseCodes,prefs.courseCodes);
  expect(repo.saved.preferredModalities,prefs.preferredModalities);
  expect(repo.saved.availableSlots.single.startTime,'09:00');
  await vm.loadRecommendations();
  expect(vm.suggestions.single.reasons,contains('Coincide con tus intereses'));
 });
 test('muestra conflicto de cupos al intentar inscribirse',()async{
  final repo=FakeApoyoRepository()..conflict=true,vm=ApoyoViewModel(repo);
  expect(await vm.enroll(7),isFalse);
  expect(vm.catalogError,contains('no tiene cupos'));
 });
 testWidgets('flujo estudiante: ver taller, inscribirse y cancelar',(tester)async{
  final repo=FakeApoyoRepository(),vm=ApoyoViewModel(repo);
  await tester.pumpWidget(ChangeNotifierProvider.value(value:vm,child:MaterialApp(theme:ThemeData(extensions:[AppColors.light]),home:const ApoyoHomePage())));
  await tester.pumpAndSettle();
  expect(find.text('Taller de prueba'),findsOneWidget);
  await tester.tap(find.text('Taller de prueba'));await tester.pumpAndSettle();
  expect(find.text('Inscribirme'),findsOneWidget);
  await tester.tap(find.text('Inscribirme'));await tester.pumpAndSettle();
  expect(find.text('Cancelar inscripción'),findsOneWidget);
  expect(repo.interactions,containsAll(['CLICK','VIEW']));
  await tester.tap(find.text('Cancelar inscripción'));await tester.pumpAndSettle();
  expect(find.text('Inscribirme'),findsOneWidget);
 });
}
