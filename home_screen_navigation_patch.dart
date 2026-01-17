// PATCH POUR home_screen.dart - Section WillPopScope
// Remplacer la section lines 266-275 dans home_screen.dart

// AVANT (problématique):
/*
            if ((tripProvider.currentStep == CustomTripType.selectScheduleTime ||
                    tripProvider.currentStep == CustomTripType.choosePickupDropLocation) &&
                tripProvider.booking == null) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
              return false; // Navigation gérée
            }
*/

// APRÈS (corrigé):
/*
            if ((tripProvider.currentStep == CustomTripType.selectScheduleTime ||
                    tripProvider.currentStep == CustomTripType.choosePickupDropLocation) &&
                tripProvider.booking == null) {
              // Rétablir la barre de navigation avant de rediriger
              Provider.of<NavigationProvider>(context, listen: false)
                  .setNavigationBarVisibility(true);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(initialTripType: CustomTripType.setYourDestination),
                ),
                (route) => false,
              );
              return false; // Navigation gérée
            }
*/

// Cette correction garantit que:
// 1. La barre de navigation est rétablie avec setNavigationBarVisibility(true)
// 2. L'initialTripType est explicitement défini sur setYourDestination
// 3. Le retour fonctionne depuis les deux accès (menu drawer et bouton planifier)
