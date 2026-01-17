// Patch pour supprimer le menu burger des écrans secondaires
// Lignes à modifier dans home_screen.dart :

// Ligne 308 - Premier Scaffold (états secondaires du trip)
// AVANT:
//   return Scaffold(
//     key: _scaffoldKey,
//     drawer: const CustomDrawer(),
//     body: Stack(

// APRÈS:
//   return Scaffold(
//     key: _scaffoldKey,
//     body: Stack(

// Ligne 360 - Deuxième Scaffold (choosePickupDropLocation et selectScheduleTime)
// AVANT:
//   return Scaffold(
//     key: _scaffoldKey,
//     drawer: const CustomDrawer(),
//     body: Stack(

// APRÈS:
//   return Scaffold(
//     key: _scaffoldKey,
//     body: Stack(

// Ligne 452 - Troisième Scaffold (setYourDestination) - GARDER LE DRAWER
// GARDER INCHANGÉ:
//   return Scaffold(
//     key: _scaffoldKey,
//     drawer: const CustomDrawer(),
//     body: Stack(
