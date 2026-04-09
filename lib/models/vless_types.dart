enum VlessTransport { tcp, ws, grpc, h2, xhttp }

String transportToString(VlessTransport transport) {
  switch (transport) {
    case VlessTransport.tcp:
      return 'tcp';
    case VlessTransport.ws:
      return 'ws';
    case VlessTransport.grpc:
      return 'grpc';
    case VlessTransport.h2:
      return 'h2';
    case VlessTransport.xhttp:
      return 'xhttp';
  }
}

VlessTransport transportFromString(String? raw) {
  switch (raw) {
    case 'ws':
      return VlessTransport.ws;
    case 'grpc':
      return VlessTransport.grpc;
    case 'h2':
      return VlessTransport.h2;
    case 'xhttp':
      return VlessTransport.xhttp;
    case 'tcp':
    default:
      return VlessTransport.tcp;
  }
}

