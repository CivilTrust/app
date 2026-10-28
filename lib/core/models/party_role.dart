enum PartyRole {
  partyA,
  partyB;

  PartyRole get other => this == partyA ? partyB : partyA;
  String get label => this == partyA ? 'Bên A' : 'Bên B';
  String businessLabel(String templateId) => templateId == 'loan-v1'
      ? (this == partyA ? 'Bên vay' : 'Bên cho vay')
      : (this == partyA ? 'Bên nhận cọc' : 'Bên đặt cọc');
}
