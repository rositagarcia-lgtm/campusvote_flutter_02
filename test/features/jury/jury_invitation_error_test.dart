import 'package:campusvote_flutter/features/jury/presentation/pages/jury_invitation_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _badResponse(int status, {String? code}) {
  final request = RequestOptions(path: '/api/fair-jury-invitations/accept');
  return DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: request,
        statusCode: status,
        data: {
          'error': {
            'code': code ?? 'ERROR',
            'message': 'Mensaje interno del backend',
          },
        },
      ),
    );
}

void main() {
  test('invitación vencida o inválida tiene un mensaje propio', () {
    expect(
      describeInvitationError(_badResponse(400, code: 'INVITATION_EXPIRED')),
      contains('no es válido o ya venció'),
    );
  });

  test('una cuenta existente no se disfraza de invitación aceptada', () {
    final request = RequestOptions(path: '/api/fair-jury-invitations/accept/new');
    final error = DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: request,
        statusCode: 409,
        data: {
          'error': {
            'code': 'CONFLICT',
            'message':
                'Esta invitación pertenece a una cuenta existente. Inicia sesión para aceptarla.',
          },
        },
      ),
    );

    expect(
      describeInvitationError(error),
      'Esta invitación pertenece a una cuenta existente. Inicia sesión para aceptarla.',
    );
  });

  test('invitación ya aceptada no culpa a la conexión', () {
    expect(
      describeInvitationError(_badResponse(409, code: 'ALREADY_ACCEPTED')),
      contains('ya fue aceptada'),
    );
  });

  test('un 403 invita a usar el correo correcto', () {
    expect(
      describeInvitationError(_badResponse(403)),
      contains('correo invitado'),
    );
  });

  test('un fallo de red sigue siendo un fallo de conexión', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/fair-jury-invitations/accept'),
      type: DioExceptionType.connectionError,
    );
    expect(
      describeInvitationError(error),
      contains('No pudimos contactar'),
    );
  });
}
