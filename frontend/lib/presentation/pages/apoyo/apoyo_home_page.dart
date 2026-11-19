
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/apoyo_academico.dart';
import '../../viewmodels/apoyo_viewmodel.dart';

class ApoyoHomePage extends StatefulWidget {
 const ApoyoHomePage({super.key});
 @override State<ApoyoHomePage> createState()=>_ApoyoHomePageState();
}
class _ApoyoHomePageState extends State<ApoyoHomePage> {
 @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_) {
  final vm=context.read<ApoyoViewModel>();
  unawaited(vm.loadCatalog());
  unawaited(vm.loadEnrollments());
  unawaited(_loadPersonalizedSuggestions(vm));
 });}
 Future<void> _loadPersonalizedSuggestions(ApoyoViewModel vm) async {
  await vm.loadPreferences();
  await vm.loadRecommendations();
 }
 @override Widget build(BuildContext context)=>DefaultTabController(length:4,child:Scaffold(
  appBar:AppBar(title:const Text('Apoyo Académico'),bottom:const TabBar(isScrollable:true,tabs:[
   Tab(text:'Catálogo'),Tab(text:'Para ti'),Tab(text:'Mis talleres'),Tab(text:'Preferencias')])),
  body:const TabBarView(children:[_CatalogTab(),_RecommendationsTab(),_EnrollmentsTab(),_PreferencesTab()])));
}
class _CatalogTab extends StatefulWidget {const _CatalogTab();@override State<_CatalogTab> createState()=>_CatalogTabState();}
class _CatalogTabState extends State<_CatalogTab>{
 final _course=TextEditingController();String? _type,_modality;
 @override void dispose(){_course.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  final vm=context.watch<ApoyoViewModel>();
  final items=vm.resources.where((r)=>_modality==null||r.modality==_modality).toList();
  return RefreshIndicator(onRefresh:()=>vm.loadCatalog(type:_type,courseCode:_course.text.trim()),child:ListView(padding:const EdgeInsets.all(16),children:[
   DropdownButtonFormField<String>(value:_type,decoration:const InputDecoration(labelText:'Tipo de actividad'),items:const[
    DropdownMenuItem(value:null,child:Text('Todos')),DropdownMenuItem(value:'TUTORING',child:Text('Tutoría')),
    DropdownMenuItem(value:'WORKSHOP',child:Text('Taller')),DropdownMenuItem(value:'MATERIAL',child:Text('Material'))],
    onChanged:(v)=>setState(()=>_type=v)),
   TextField(controller:_course,decoration:const InputDecoration(labelText:'Código de curso',hintText:'Ej. MAT101')),
   DropdownButtonFormField<String>(value:_modality,decoration:const InputDecoration(labelText:'Modalidad'),items:const[
    DropdownMenuItem(value:null,child:Text('Todas')),DropdownMenuItem(value:'PRESENCIAL',child:Text('Presencial')),
    DropdownMenuItem(value:'REMOTO',child:Text('Remoto')),DropdownMenuItem(value:'HIBRIDO',child:Text('Híbrido'))],
    onChanged:(v)=>setState(()=>_modality=v)),
   const SizedBox(height:8),
   FilledButton.icon(onPressed:vm.loadingCatalog?null:()=>vm.loadCatalog(type:_type,courseCode:_course.text.trim()),icon:const Icon(Icons.search),label:const Text('Aplicar filtros')),
   if(vm.catalogError!=null)_ErrorBox(vm.catalogError!,()=>vm.loadCatalog(type:_type,courseCode:_course.text.trim())),
   if(vm.loadingCatalog&&vm.resources.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Center(child:CircularProgressIndicator())),
   if(items.isEmpty&&!vm.loadingCatalog&&vm.catalogError==null)const Padding(padding:EdgeInsets.all(24),child:Text('No hay actividades disponibles con estos filtros.')),
   for(final item in items)_ResourceTile(resource:item),
   if(vm.hasMore)OutlinedButton(onPressed:vm.loadingCatalog?null:()=>vm.loadCatalog(more:true),child:Text(vm.loadingCatalog?'Cargando…':'Cargar más')),
   if(vm.loadingCatalog&&vm.resources.isNotEmpty)const Center(child:CircularProgressIndicator()),
  ]));
 }
}
class _RecommendationsTab extends StatelessWidget{
 const _RecommendationsTab();
 @override Widget build(BuildContext context){
  final vm=context.watch<ApoyoViewModel>();
  return RefreshIndicator(onRefresh:vm.loadRecommendations,child:ListView(padding:const EdgeInsets.all(16),children:[
   const Text('Sugerencias basadas en tus preferencias y actividad.'),
   if(vm.recommendationsError!=null)_ErrorBox(vm.recommendationsError!,vm.loadRecommendations),
   if(vm.loadingRecommendations&&vm.suggestions.isEmpty)const Center(child:Padding(padding:EdgeInsets.all(24),child:CircularProgressIndicator())),
   if(vm.suggestions.isEmpty&&!vm.loadingRecommendations&&vm.recommendationsError==null)const Padding(padding:EdgeInsets.all(20),child:Text('Aún no hay sugerencias. Explora el catálogo y completa tus preferencias.')),
   for(final s in vm.suggestions)_ResourceTile(resource:s.resource,reasons:s.reasons),
  ]));
 }
}
class _EnrollmentsTab extends StatelessWidget{
 const _EnrollmentsTab();
 @override Widget build(BuildContext context){
  final vm=context.watch<ApoyoViewModel>();
  return RefreshIndicator(onRefresh:vm.loadEnrollments,child:ListView(padding:const EdgeInsets.all(16),children:[
   if(vm.enrollmentsError!=null)_ErrorBox(vm.enrollmentsError!,vm.loadEnrollments),
   if(vm.loadingEnrollments&&vm.myEnrollments.isEmpty)const Center(child:Padding(padding:EdgeInsets.all(24),child:CircularProgressIndicator())),
   if(vm.myEnrollments.isEmpty&&!vm.loadingEnrollments&&vm.enrollmentsError==null)const Padding(padding:EdgeInsets.all(20),child:Text('Todavía no tienes inscripciones activas.')),
   for(final e in vm.myEnrollments)Card(child:ListTile(isThreeLine:true,title:Text(e.title),
    subtitle:Text(_formatDate(e.startAt)+' · '+_modality(e.modality)+'\n'+(e.location??'Ubicación por confirmar')),
    trailing:TextButton(onPressed:()async{final ok=await context.read<ApoyoViewModel>().cancelEnrollment(e.resourceId);
     if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(ok?'Inscripción cancelada.':context.read<ApoyoViewModel>().actionError??'No se pudo cancelar.'),
      action:ok?null:SnackBarAction(label:'Reintentar',onPressed:(){context.read<ApoyoViewModel>().cancelEnrollment(e.resourceId);})));
    },child:const Text('Cancelar')))),
  ]));
 }
}
class _PreferencesTab extends StatefulWidget{const _PreferencesTab();@override State<_PreferencesTab> createState()=>_PreferencesTabState();}
class _PreferencesTabState extends State<_PreferencesTab>{
 final _interests=TextEditingController(),_courses=TextEditingController(),_zone=TextEditingController(text:'America/Lima');
 final _start=TextEditingController(text:'09:00'),_end=TextEditingController(text:'17:00');
 int _weekday=0;final Set<String> _modalities={};List<AvailabilitySlot> _slots=[];bool _loaded=false;
 @override void dispose(){_interests.dispose();_courses.dispose();_zone.dispose();_start.dispose();_end.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  final vm=context.watch<ApoyoViewModel>();
  if(!_loaded&&!vm.loadingPreferences&&vm.preferencesError==null){_loaded=true;_interests.text=vm.preferences.interests.join(', ');
   _courses.text=vm.preferences.courseCodes.join(', ');_zone.text=vm.preferences.timeZone;
   _slots=[...vm.preferences.availableSlots];_modalities.addAll(vm.preferences.preferredModalities);}
  return ListView(padding:const EdgeInsets.all(16),children:[
   const Text('Cuéntanos qué temas y horarios prefieres. Puedes editarlo cuando quieras.'),
   if(vm.loadingPreferences&&!_loaded)const LinearProgressIndicator(),
   if(vm.preferencesError!=null)_ErrorBox(vm.preferencesError!,vm.loadPreferences),
   TextField(controller:_interests,decoration:const InputDecoration(labelText:'Intereses separados por coma')),
   TextField(controller:_courses,decoration:const InputDecoration(labelText:'Cursos separados por coma')),
   TextField(controller:_zone,decoration:const InputDecoration(labelText:'Zona horaria (IANA)')),
   const SizedBox(height:12),const Text('Modalidades preferidas'),
   Wrap(spacing:4,children:[_modeChip('PRESENCIAL'),_modeChip('REMOTO'),_modeChip('HIBRIDO')]),
   const SizedBox(height:12),const Text('Bloques disponibles (máximo 14)'),
   DropdownButton<int>(value:_weekday,items:const[
    DropdownMenuItem(value:0,child:Text('Lunes')),DropdownMenuItem(value:1,child:Text('Martes')),
    DropdownMenuItem(value:2,child:Text('Miércoles')),DropdownMenuItem(value:3,child:Text('Jueves')),
    DropdownMenuItem(value:4,child:Text('Viernes')),DropdownMenuItem(value:5,child:Text('Sábado')),
    DropdownMenuItem(value:6,child:Text('Domingo'))],onChanged:(v)=>setState(()=>_weekday=v??0)),
   Row(children:[Expanded(child:TextField(controller:_start,decoration:const InputDecoration(labelText:'Desde HH:MM'))),
    const SizedBox(width:12),Expanded(child:TextField(controller:_end,decoration:const InputDecoration(labelText:'Hasta HH:MM')))]),
   OutlinedButton.icon(onPressed:_slots.length>=14?null:(){
    final s=AvailabilitySlot(_weekday,_start.text.trim(),_end.text.trim());
    if(!_validTime(s.startTime)||!_validTime(s.endTime)||s.startTime.compareTo(s.endTime)>=0){
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Usa horas HH:MM y verifica que Desde sea anterior a Hasta.')));return;}
    setState(()=>_slots.add(s));
   },icon:const Icon(Icons.add),label:const Text('Agregar horario')),
   for(var i=0;i<_slots.length;i++)ListTile(dense:true,title:Text(_weekdayName(_slots[i].weekday)+' '+_slots[i].startTime+'–'+_slots[i].endTime),
    trailing:IconButton(tooltip:'Quitar horario',icon:const Icon(Icons.close),onPressed:()=>setState(()=>_slots.removeAt(i)))),
   FilledButton(onPressed:vm.savingPreferences?null:()async{
    List<String> split(String v)=>v.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toSet().toList();
    final value=AcademicPreferences(interests:split(_interests.text),courseCodes:split(_courses.text),availableSlots:_slots,
     preferredModalities:_modalities.toList(),timeZone:_zone.text.trim());
    final ok=await context.read<ApoyoViewModel>().savePreferences(value);
    if(ok)await context.read<ApoyoViewModel>().loadRecommendations();
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'Preferencias guardadas.':context.read<ApoyoViewModel>().preferencesError??'No se pudieron guardar.')));
   },child:Text(vm.savingPreferences?'Guardando…':'Guardar preferencias')),
  ]);
 }
 Widget _modeChip(String mode)=>FilterChip(label:Text(_modality(mode)),selected:_modalities.contains(mode),
  onSelected:(selected)=>setState(()=>selected?_modalities.add(mode):_modalities.remove(mode)));
}
class _ResourceTile extends StatelessWidget{
 final AcademicResource resource;final List<String> reasons;
 const _ResourceTile({required this.resource,this.reasons=const[]});
 @override Widget build(BuildContext context){
  final colors=AppColors.of(context);
  final seats=resource.type=='WORKSHOP'&&resource.availableSeats!=null?' · Cupos: '+resource.availableSeats.toString():'';
  final details=_type(resource.type)+' · '+_modality(resource.modality)+'\n'+_formatDate(resource.startAt)+seats+
   (reasons.isEmpty?'':'\n'+reasons.join(' · '));
  return Card(child:ListTile(isThreeLine:true,title:Text(resource.title,style:const TextStyle(fontWeight:FontWeight.w600)),
   subtitle:Text(details,maxLines:4,overflow:TextOverflow.ellipsis),trailing:Icon(Icons.chevron_right,color:colors.primary),
   onTap:()async{
    final vm=context.read<ApoyoViewModel>();await vm.recordInteraction(resource.id,'CLICK');await vm.recordInteraction(resource.id,'VIEW');
    if(context.mounted)Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>_ResourceDetailPage(resource:resource)));
   }));
 }
}
class _ResourceDetailPage extends StatefulWidget{
 final AcademicResource resource;const _ResourceDetailPage({required this.resource});
 @override State<_ResourceDetailPage> createState()=>_ResourceDetailPageState();
}
class _ResourceDetailPageState extends State<_ResourceDetailPage>{
 late Future<AcademicResource?> _detail;
 @override void initState(){super.initState();_detail=context.read<ApoyoViewModel>().loadResource(widget.resource.id);}
 void _retry(){setState(()=>_detail=context.read<ApoyoViewModel>().loadResource(widget.resource.id));}
 @override Widget build(BuildContext context){
  final vm=context.watch<ApoyoViewModel>();final enrolled=vm.isEnrolled(widget.resource.id);
  return Scaffold(appBar:AppBar(title:const Text('Detalle de actividad')),body:FutureBuilder<AcademicResource?>(
   future:_detail,builder:(context,snapshot){final resource=snapshot.data??widget.resource;
    return ListView(padding:const EdgeInsets.all(20),children:[
     if(snapshot.connectionState==ConnectionState.waiting)const LinearProgressIndicator(),
     if(vm.resourceError!=null)_ErrorBox(vm.resourceError!,_retry),
     Text(resource.title,style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),Text(resource.description),
     const SizedBox(height:16),Text('Tipo: '+_type(resource.type)),Text('Modalidad: '+_modality(resource.modality)),
     Text('Horario: '+_formatDate(resource.startAt)+(resource.endAt==null?'':' – '+_formatDate(resource.endAt))),
     if(resource.location!=null)Text('Lugar: '+resource.location!),
     if(resource.courseCodes.isNotEmpty)Text('Cursos: '+resource.courseCodes.join(', ')),
     if(resource.availableSeats!=null)Text('Cupos disponibles: '+resource.availableSeats.toString()),
     if(resource.url!=null)SelectableText('Enlace: '+resource.url!),
     if(vm.catalogError!=null)_ErrorBox(vm.catalogError!,()=>vm.loadCatalog()),
     if(vm.actionError!=null)_ErrorBox(vm.actionError!,() {
      if(enrolled){context.read<ApoyoViewModel>().cancelEnrollment(resource.id);}
      else{context.read<ApoyoViewModel>().enroll(resource.id);}
     }),
     if(resource.type=='WORKSHOP')FilledButton.icon(
      onPressed:(!enrolled&&resource.availableSeats==0)?null:()async{
       final ok=enrolled?await context.read<ApoyoViewModel>().cancelEnrollment(resource.id):await context.read<ApoyoViewModel>().enroll(resource.id);
       if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(ok?(enrolled?'Inscripción cancelada.':'Inscripción confirmada.'):context.read<ApoyoViewModel>().actionError??'No se pudo completar la operación.'),
        action:ok?null:SnackBarAction(label:'Reintentar',onPressed:(){if(enrolled){context.read<ApoyoViewModel>().cancelEnrollment(resource.id);}else{context.read<ApoyoViewModel>().enroll(resource.id);}})));
      },icon:Icon(enrolled?Icons.event_busy:Icons.event_available),label:Text(enrolled?'Cancelar inscripción':'Inscribirme')),
    ]);
   }),);
 }
}
class _ErrorBox extends StatelessWidget{
 final String message;final VoidCallback retry;
 const _ErrorBox(this.message,this.retry);
 @override Widget build(BuildContext context)=>Card(color:Theme.of(context).colorScheme.errorContainer,
  child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text(message),Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:retry,icon:const Icon(Icons.refresh),label:const Text('Reintentar')))])));
}
String _type(String v)=>switch(v){'TUTORING'=>'Tutoría','WORKSHOP'=>'Taller','MATERIAL'=>'Material',_=>v};
String _modality(String? v)=>switch(v){'PRESENCIAL'=>'Presencial','REMOTO'=>'Remoto','HIBRIDO'=>'Híbrido',_=>'Por confirmar'};
String _weekdayName(int v)=>const['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'][v.clamp(0,6).toInt()];
bool _validTime(String v){final p=v.split(':');if(p.length!=2)return false;final h=int.tryParse(p[0]),m=int.tryParse(p[1]);
 return h!=null&&m!=null&&h>=0&&h<24&&m>=0&&m<60&&p[0].length==2&&p[1].length==2;}
String _formatDate(DateTime? value){
 if(value==null)return 'Horario por confirmar';final d=value.toLocal();
 final date=d.day.toString().padLeft(2,'0')+'/'+d.month.toString().padLeft(2,'0')+'/'+d.year.toString();
 final time=d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');return date+' a las '+time;
}
