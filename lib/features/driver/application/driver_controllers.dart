import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/driver_repository.dart';
import '../data/models/vehiculo.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.watch(apiClientProvider));
});

final vehiculosProvider = FutureProvider<List<Vehiculo>>((ref) async {
  return ref.watch(driverRepositoryProvider).getVehiculos();
});
