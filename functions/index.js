/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const logger = require("firebase-functions/logger");
const functions = require('firebase-functions');
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");
const { google } = require("googleapis");

admin.initializeApp();
const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;
// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started
const JobStatus = {
  UPDATE: 0,
  DELETE: 1,
};
const SCOPES = ['https://www.googleapis.com/auth/firebase.messaging'];

const projectId = "misy-95336";
const location = "us-central1";
// const location = "us-east1";
const _senderId = "1062917624003";

//collects
const usersCollection = "users";
const bookingsCollection = "bookingRequest";
const cancelledBookingCollection = "cancelledBooking";
const sendNotificationFunctionUrl = `https://${location}-${projectId}.cloudfunctions.net/sendNotificationFunction`;
const updateJobUrl = `https://${location}-${projectId}.cloudfunctions.net/updateSchedulerJob`;
const BookingConfirmStatus = {
  Not_ASSIGNED: 0,
  PENDING: 1,
  ACCEPTED: 2,
};
const BookingStatus = {
  PENDING_REQUEST: 0,
  ACCEPTED: 1,
  DRIVER_REACHED: 2,
  RIDE_STARTED: 3,
  DESTINATION_REACHED: 4,
  RIDE_COMPLETE: 5,
};
const translations = {
  en: {
    bookingCancelNotConfirmInTimeString: `Your booking has been canceled because it wasn’t confirmed in time.` ,
    bookingCancelString: `Your booking has been canceled due` +
      ` to no response from driver.`,
    bookingCancelled:"Booking Cancelled",
    bookingConfirmationRequired: "Booking Confirmation Required",
    bookingConfirmationRequiredMsg: "Your booking was scheduled. Please review and confirm booking time.",


  },
  mg: {
    bookingCancelString: "Nofoanana ny famandrihanao satria tsy nisy sofera namaly",
  bookingCancelled:"Nofoanana ny famandrihana",
  bookingCancelNotConfirmInTimeString:"Nofoanana ny famandrihanao satria tsy voamarika ara-potoana.",
  bookingConfirmationRequired: "Mila fanamafisana ny famandrihana",
  bookingConfirmationRequiredMsg: "Voalahatra ny famandrihanao. Azafady, jereo ary hamafiso ny ora hanaovana ny famandihana",
  },
  fr: {
    bookingCancelString: "Votre réservation a été annulée car aucun chauffeur n'a répondu.",
    bookingCancelNotConfirmInTimeString:"Votre réservation a été annulée car elle n'a pas été confirmée à temps.",
  bookingCancelled:"Réservation annulée",
  bookingConfirmationRequired: "Confirmation de réservation requise",
  bookingConfirmationRequiredMsg: "Votre réservation a été programmée. Veuillez vérifier et confirmer l'heure de votre réservation.",
  },
};
function translate(key, lang = "en") {
  return translations[lang] && translations[lang][key]
    ? translations[lang][key]
    : translations["en"][key]; // fallback to English if translation not found
}

exports.mainFunction = functions.https.onRequest(async (req, res) => {
  try {
    // Ensure request is a JSON payload
    if (req.method !== 'POST' || !req.body) {
      res.status(400).send({ message: "Invalid request" });
      return;
    }

    // Request body is already parsed as JSON
    const requestBody = req.body;
    console.log("requestBody:", requestBody);
    const decodedBody =
      Buffer.from(req.body, "base64").toString("utf8");
    const requestBody2 = JSON.parse(decodedBody);
    const { bookingId } = requestBody2;

    console.log("bookingId:", bookingId);

    if (!bookingId) {
      res.status(400).send({ message: "Booking id required." });
      return;
    }

    // Fetch booking document from Firestore
    const bookingDoc = await db.collection(bookingsCollection)
      .doc(bookingId).get();

    if (!bookingDoc.exists) {
      res.status(404).send({ message: "Booking not found." });
      const deleteJobData = {
        bookingId: bookingId,
        jobStatus: JobStatus.DELETE,
      };
      await axios.post(updateJobUrl, deleteJobData);
      return;
    }
    const bookingData = bookingDoc.data();
    const currentTime = admin.firestore.Timestamp.now(); // Get the current Firestore timestamp

    const timeDifference = bookingData.scheduleTime.seconds - currentTime.seconds; // Calculate time difference in seconds
    console.log("timer diffrenece data is ::::: ", timeDifference);

    if (BookingStatus.PENDING_REQUEST == bookingData.status && timeDifference < 1400) {
      if (timeDifference < 150) {
        console.log("inside if run :::::>>>> ")
        const customerDoc = await db.collection(usersCollection)
          .doc(bookingData.requestBy).get();
        if (!customerDoc.exists) {
          res.status(404).send({ message: "Customer not found." });
          return;
        }
        const customerData = customerDoc.data();
        console.log("Customer data is ::::: ", customerData);
        notificationData = {
          tokens: customerData.deviceId,
          title: translate("bookingCancelled", customerData.preferedLanguage),
          body: translate("bookingCancelString", customerData.preferedLanguage),
          bookingId: bookingId,
          userId: customerData.id,

        };

        // notificationResponse =
        await axios.post(
          sendNotificationFunctionUrl, notificationData);

        console.log("Transfering the booking into cancle");
        bookingData.cancelledBy = "Scheduler";
        bookingData.cancelledByUserId = "cloud_function";

        await db.collection(cancelledBookingCollection)
          .doc(bookingData.id).set(bookingData);
        db.collection(bookingsCollection)
          .doc(bookingData.id).delete();
        const deleteJobData = {
          bookingId: bookingId,
          jobStatus: JobStatus.DELETE,
        };


        await axios.post(updateJobUrl, deleteJobData);

        console.log({ message: "Job DELETED SUCCESSFULLY" });
      } else {
        console.log("inside ::::>>>>> else pending run :::::>>>> ");
        const rescheduleTime = currentTime.toDate();
        rescheduleTime.setUTCMinutes(rescheduleTime.getUTCMinutes() + 19);
        // Extract updated values for cron expression
        const newMinutes = rescheduleTime.getUTCMinutes();
        const newHours = rescheduleTime.getUTCHours();
        const newDayOfMonth = rescheduleTime.getUTCDate();
        const newMonth = rescheduleTime.getUTCMonth() + 1;
        // Months are zero-based in JavaScript

        // Format the cron expression (UTC timezone)
        const newSchedule =
          `${newMinutes}  ${newHours} ${newDayOfMonth} ${newMonth} *`;

        console.log({ "newSchedule time ::::: >>>>": newSchedule });
        console.log({ message: "<<:::: JOB SCHEDULER UPDATED SUCCESSFULLY ::::>>" });

        const updatedJobData = {
          newSchedule: newSchedule,
          bookingId: bookingId,
          jobStatus: JobStatus.UPDATE,
        };


        await axios.post(updateJobUrl, updatedJobData);
        db.collection(bookingsCollection)
          .doc(bookingData.id).update({
            isBookingConfirmed: BookingConfirmStatus.ACCEPTED,
            acceptedBy: null,
            acceptedTime: null,
            status: 0,
            startRide: true,
            isSchedule: false,

          });
        console.log("BOOKING SEND AS LIVE DONE BEFORE 20 MIN")
      }
    }

    else if (BookingStatus.ACCEPTED == bookingData.status && bookingData.isSchedule) {
      console.log("inside if accepted run :::::>>>> ")
      const driverDoc = await db.collection(usersCollection)
        .doc(bookingData.acceptedBy).get();
      if (!driverDoc.exists) {
        res.status(404).send({ message: "Driver not found." });
        return;
      }
      const driverData = driverDoc.data();
      console.log("Driver data is ::::: ", driverData);
      if (BookingStatus.ACCEPTED == bookingData.status && bookingData.isBookingConfirmed == BookingConfirmStatus.Not_ASSIGNED) {
        notificationData = {
          tokens: driverData.deviceId,
          title: translate("bookingConfirmationRequired", driverData.preferedLanguage),
          body: translate("bookingConfirmationRequiredMsg", driverData.preferedLanguage),
          bookingId: bookingId,
          userId: driverData.id,

        };

        // notificationResponse =
        await axios.post(
          sendNotificationFunctionUrl, notificationData);
        const rescheduleTime = currentTime.toDate();
        rescheduleTime.setUTCMinutes(rescheduleTime.getUTCMinutes() + 15);
        // Extract updated values for cron expression
        const newMinutes = rescheduleTime.getUTCMinutes();
        const newHours = rescheduleTime.getUTCHours();
        const newDayOfMonth = rescheduleTime.getUTCDate();
        const newMonth = rescheduleTime.getUTCMonth() + 1;
        // Months are zero-based in JavaScript

        // Format the cron expression (UTC timezone)
        const newSchedule =
          `${newMinutes}  ${newHours} ${newDayOfMonth} ${newMonth} *`;

        console.log({ "newSchedule time ::::: >>>>": newSchedule });

        const updatedJobData = {
          newSchedule: newSchedule,
          bookingId: bookingId,
          jobStatus: JobStatus.UPDATE,
        };


        await axios.post(updateJobUrl, updatedJobData);
        db.collection(bookingsCollection)
          .doc(bookingData.id).update({
            isBookingConfirmed: BookingConfirmStatus.PENDING,

          });
        console.log({ message: "Job Updated SUCCESSFULLY" });
      } else if (BookingStatus.ACCEPTED == bookingData.status && bookingData.isBookingConfirmed == BookingConfirmStatus.PENDING) {
        notificationData = {
          tokens: driverData.deviceId,
          title: translate("bookingCancelled", driverData.preferedLanguage),
          body: translate("bookingCancelNotConfirmInTimeString", driverData.preferedLanguage),
          bookingId: bookingId,
          userId: driverData.id,

        };

        // notificationResponse =
        await axios.post(
          sendNotificationFunctionUrl, notificationData);
        //   const rescheduleTime = bookingData.scheduleTime.toDate();
        //   rescheduleTime.setMinutes(rescheduleTime.getMinutes() - 2);
        // // Extract updated values for cron expression
        // const newMinutes = rescheduleTime.getMinutes(); // Get local minutes
        // const newHours = rescheduleTime.getHours(); // Get local hours
        // const newDayOfMonth = rescheduleTime.getDate(); // Get local day of the month
        // const newMonth = rescheduleTime.getMonth() + 1;
        // // Months are zero-based in JavaScript

        // // Format the cron expression (UTC timezone)
        // const newSchedule =
        //   `${newMinutes}  ${newHours} ${newDayOfMonth} ${newMonth} *`;

        // console.log({ "newSchedule time ::::: >>>>": newSchedule });

        const updatedJobData = {
          // newSchedule: newSchedule,
          bookingId: bookingId,
          jobStatus: JobStatus.DELETE,
        };


        await axios.post(updateJobUrl, updatedJobData);
        const bookingDataCopy = bookingData;
        db.collection(bookingsCollection)
          .doc(bookingData.id).update({
            isBookingConfirmed: BookingConfirmStatus.ACCEPTED,
            acceptedBy: null,
            acceptedTime: null,
            status: 0,
            startRide: true,
            isSchedule: false,

          });
        const newDocRef = db.collection(cancelledBookingCollection).doc();

        bookingDataCopy.id = newDocRef.id;
        bookingDataCopy.cancelledBy = "Scheduler";
        bookingDataCopy.cancelledByUserId = "cloud_function";
        bookingDataCopy.reason = "Booking not confirmed in time";
        console.log(`New Cancelled Booking Insert SUCCESSFULLY ${newDocRef.id}`);
        newDocRef.set(bookingDataCopy);
        console.log({ message: "Job Updated SUCCESSFULLY" });
      } else {
        console.log({ message: "Nothing happen due to some issue" });
        const updatedJobData = {
          // newSchedule: newSchedule,
          bookingId: bookingId,
          jobStatus: JobStatus.DELETE,
        };


        await axios.post(updateJobUrl, updatedJobData);
      }

    }
    else {
      console.log("inside else run delete job not worked :::::>>>> ")
      const updatedJobData = {
        // newSchedule: newSchedule,
        bookingId: bookingId,
        jobStatus: JobStatus.DELETE,
      };


      await axios.post(updateJobUrl, updatedJobData);
    }
    // Handle other logic here
    res.status(200).send({ message: "Success" });

  } catch (error) {
    console.error("Error in main function:", error);
    res.status(500).send({ error: error.message });
  }
});

exports.updateSchedulerJob = functions.https.onRequest(async (req, res) => {
  try {
    console.log("Update Job Request :", req.body);

    if (req.method !== "POST") {
      res.status(400).send({ "message": "Please send a POST request" });
      return;
    }

    const bookingId = req.body.bookingId;
    const newSchedule = req.body.newSchedule || null;
    const jobStatus = req.body.jobStatus;


    if (!bookingId) {
      res.status(400).send({ "message": "bookingId required" });
      return;
    }

    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });

    console.log("Auth  :", auth);

    const authClient = await auth.getClient();

    console.log("Auth Client   :", authClient);



    const cloudScheduler = google.cloudscheduler({
      version: "v1",
      auth: authClient,
    });

    console.log("Cloud Scheduler   :", cloudScheduler);


    const jobPath =
      `projects/${projectId}/locations/${location}/jobs/${bookingId}`;

    console.log("JOB PATH   :", jobPath);

    const job = await cloudScheduler.
      projects.locations.jobs.get({ name: jobPath });
    console.log("job   :", job);

    if (jobStatus === JobStatus.UPDATE) {
      job.data.schedule = newSchedule;

      await cloudScheduler.projects.locations.jobs.patch({
        name: jobPath,
        updateMask: "schedule",
        requestBody: job.data,
      });

      // console.log("updatedJob   :", updatedJob);
      res.status(200).send({ message: "ok" });
      return;
    } else if (jobStatus === JobStatus.DELETE) {
      job.data.schedule = newSchedule;

      // const deleteJob =
      await cloudScheduler.projects.locations.jobs.delete({ name: jobPath });

      console.log("Job deleted:", jobPath);
      res.status(200).send({ message: "ok" });

      return;
    }
  } catch (error) {
    console.error("Error updating job:", error);
    res.status(500).send({ "error": error.message });
  }
});

exports.sendNotificationFunction = functions.https.onRequest(
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(400).send({ "message": "Please send a POST request" });
        return;
      }
      const deviceTokens = req.body.tokens;
      const messageTitle = req.body.title;
      const messageBody = req.body.body;
      const bookingId = req.body.bookingId;
      const isRescheduling = req.body.isRescheduling || false;
      const rescheduleTimeString = req.body.rescheduleTime || null;
      const userId = req.body.userId || null;
      const imageUrl = req.body.imageUrl || null;
      const isPayment = req.body.isPayment || false;
      const isReview = req.body.isReview || false;

      const notificationCollection = "notifications";


      console.log("Notification Request :", req.body);


      if (!messageTitle) {
        res.status(400).send({ "message": "Title is required" });
        return;
      }

      if (!messageBody) {
        res.status(400).send({ "message": "Body is required" });
        return;
      }


      const message = {
        notification: {
          title: messageTitle,
          body: messageBody,
        },
        data: {
          InnerData: JSON.stringify({
            screen: "booking",
            bookingId: bookingId,
            isPayment: isPayment,
            isReview: isReview,
          }),
        },
        tokens: deviceTokens,
      };

      let id = "";

      if (userId !== null && userId !== "") {
        // Ensure userId is not null or an empty string
        try {
          const request = {
            title: messageTitle,
            body: messageBody,
            data: {
              InnerData: {
                screen: "booking",
                bookingId: bookingId,
                imageAssetUrl: imageUrl || null,
                isPayment: isPayment,
                isReview: isReview,
              },

            },
            createdAt: Timestamp.now(),
          };

          const refrance =
            await db.collection(usersCollection)
              .doc(userId)
              .collection(notificationCollection)
              .add(request);

          id = refrance.id;

          db.collection(usersCollection).doc(userId).update({
            unreadNotificationsCount: admin.firestore.FieldValue.increment(1),
          });

          console.log("Notification added successfully");
        } catch (error) {
          console.error("Error adding notification:", error);
        }
      }
      console.log("id or notification status ::::::::", id);

      console.log({ "Notification Payload": message });


      if (isRescheduling === true) {
        const rescheduleTime = new Date(rescheduleTimeString);
        // Extract updated values for cron expression
        const newMinutes = rescheduleTime.getUTCMinutes();
        const newHours = rescheduleTime.getUTCHours();
        const newDayOfMonth = rescheduleTime.getUTCDate();
        const newMonth = rescheduleTime.getUTCMonth() + 1;
        // Months are zero-based in JavaScript

        // Format the cron expression (UTC timezone)
        const newSchedule =
          `${newMinutes}  ${newHours} ${newDayOfMonth} ${newMonth} *`;

        console.log({ "newSchedule": newSchedule });

        const updatedJobData = {
          newSchedule: newSchedule,
          bookingId: bookingId,
          jobStatus: JobStatus.UPDATE,
        };


        await axios.post(updateJobUrl, updatedJobData);
      }

      const accessToken = await getAccessToken();
      let singleToken = "";
      if (deviceTokens.length != 0) {
        if (deviceTokens.length > 1) {
          singleToken =
            await getMultipleDeviceToken(deviceTokens, accessToken);
        } else {
          singleToken = deviceTokens[0];
        }

        console.log({ "SINGLE TOKEN TOKEN": singleToken });
        console.log({ "ACCESS TOKEN": accessToken });

        const invalidTokens = [];

        for (let i = 0; i < deviceTokens.length; i++) {
          const re = {
            message: {
              notification: {
                title: messageTitle,
                body: messageBody,
              },
              data: {
                id: id,
                userId: userId,
              },
              token: deviceTokens[i],
            },
          };

          console.log({ "Notification Payload": re }, deviceTokens[i]);

          try {
            const response = await axios.post(
              `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
              JSON.stringify(re),
              {
                headers: {
                  "Authorization": `Bearer ${accessToken}`,
                  "Content-Type": "application/json",
                },
              },
            );

            console.log(`Notification sent successfully
            to ${deviceTokens[i]}:`, response.data);
          } catch (error) {
            console.log(`Error sending notification
            to ${deviceTokens[i]}:`, error.message);

            // Check if error response exists and if status is 404
            if (error.response && error.response.status === 404) {
              invalidTokens.push(deviceTokens[i]);
            }
          }
        }


        console.log("Invalid Tokens:", invalidTokens);
        console.log("Device  Tokens:", deviceTokens);

        const newTokens = deviceTokens.
          filter((token) => !invalidTokens.includes(token));

        console.log("New  Device Tokens:", newTokens);

        console.log("Notification sent successfully:");

      }

      res.status(200).send({ message: "ok" });
    } catch (error) {
      console.error("Error in sending notification:", error);
      res.status(200).send({ "message": "OK" });
    }


    /**
               * Retrieves the OAuth 2.0 access token for Firebase Messaging
               * using the service account key file.
               *
               * @return {Promise<string>} A
                *promise that resolves with the access token.
               */
    function getAccessToken() {
      return new Promise((resolve, reject) => {
        const key =
          require("./serviceAccountKey.json");

        const jwtClient = new google.auth.JWT(
          key.client_email,
          null,
          key.private_key,
          ["https://www.googleapis.com/auth/firebase.messaging"], // Scope for FCM access
        );

        jwtClient.authorize((err, tokens) => {
          if (err) {
            reject(err); // Reject the promise on error
            return;
          }
          resolve(tokens.access_token);
        });
      });
    }

    /**
            * Sends a notification to multiple device
            * tokens and retrieves the notification key.
            *
            * @param {Array<string>} deviceIds - The
            * list of device IDs to send notifications to.
            * @param {string} apiAuthToken - The API authorization token.
            * @return {Promise<string>} A promise that
             * resolves with the notification key or an empty string.
          */
    async function getMultipleDeviceToken(deviceIds, apiAuthToken) {
      const request = {
        operation: "create",
        notification_key_name: generateNotificationId(),
        registration_ids:
          deviceIds,
      };

      const headers = {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiAuthToken}`,
        "access_token_auth": "true",
        "project_id": projectId,
      };

      console.log("Notification sending---------");

      try {
        const response = await axios.post(
          "https://fcm.googleapis.com/fcm/notification",
          JSON.stringify(request),
          { headers },
        );

        if (response.status === 200) {
          const jsonResponse = response.data;
          console.log("RESPONSE IS :::-----", response);
          console.log("RESPONSE IS :::-----", response.data);
          console.log("RESPONSE IS :::-----", jsonResponse);
          if (jsonResponse.notification_key) {
            return jsonResponse.notification_key;
          }
          return "";
        } else {
          return "";
        }
      } catch (error) {
        console.error("Error sending notification:", error);
        return "";
      }
    }

    /**
               * Generates a unique notification ID using
               *random characters and the current timestamp.
               *
               * @return {string} A unique notification ID.
               */
    function generateNotificationId() {
      const allowedChars =
        "abcdefghijklmnopqrstuvwxyz0123456789";
      const idLength = 35; // Maximum length of the ID

      // Generate random characters from the allowed characters
      let id = "";
      for (let i = 0; i < idLength; i++) {
        const randomIndex =
          Math.floor(Math.random() * allowedChars.length);
        id += allowedChars[randomIndex];
      }

      return `${id}${Date.now()}`; // Append current timestamp
    }
  });

/**
 * Cloud Function exécutée automatiquement toutes les heures
 * pour nettoyer les courses réservées expirées
 *
 * Cette fonction :
 * 1. Trouve toutes les courses programmées (isSchedule = true)
 * 2. Dont le scheduleTime est dans le passé
 * 3. Qui n'ont pas encore été acceptées (status < ACCEPTED)
 * 4. Les marque comme expirées et annulées
 */
exports.cleanupExpiredScheduledBookings = onSchedule(
  {
    schedule: 'every 1 hours', // S'exécute toutes les heures
    timeZone: 'Indian/Antananarivo', // Timezone Madagascar
    region: 'us-central1',
  },
  async (event) => {
    try {
      const now = admin.firestore.Timestamp.now();

      logger.info(`🧹 Starting cleanup of expired scheduled bookings at ${now.toDate()}`);

      // Rechercher toutes les courses programmées expirées et non acceptées
      const expiredBookingsSnapshot = await db.collection(bookingsCollection)
        .where('isSchedule', '==', true)
        .where('scheduleTime', '<', now)
        .where('status', '<', BookingStatus.ACCEPTED)
        .get();

      if (expiredBookingsSnapshot.empty) {
        logger.info('✅ No expired scheduled bookings found');
        return null;
      }

      logger.info(`📋 Found ${expiredBookingsSnapshot.size} expired scheduled bookings to clean up`);

      // Utiliser batch pour mettre à jour plusieurs documents en une fois
      const batch = db.batch();
      const cleanedBookingIds = [];

      for (const doc of expiredBookingsSnapshot.docs) {
        const bookingData = doc.data();
        const bookingId = doc.id;

        logger.info(`Processing expired booking: ${bookingId} (scheduled for ${bookingData.scheduleTime.toDate()})`);

        // Déplacer vers la collection cancelledBooking
        const cancelledBookingRef = db.collection(cancelledBookingCollection).doc(bookingId);
        batch.set(cancelledBookingRef, {
          ...bookingData,
          status: BookingStatus.RIDE_COMPLETE, // Marquer comme complété/fermé
          isExpired: true,
          expiredAt: now,
          cancelReason: 'Booking expired - scheduled time passed without acceptance',
          cancelledAt: now,
          cancelledBy: 'system_cleanup',
        });

        // Supprimer de la collection bookingRequest
        batch.delete(doc.ref);

        cleanedBookingIds.push(bookingId);

        // Optionnel : Envoyer une notification au client
        try {
          const userDoc = await db.collection(usersCollection).doc(bookingData.userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            const deviceTokens = userData.deviceTokens || [];
            const userLanguage = userData.language || 'fr';

            if (deviceTokens.length > 0) {
              // Envoyer notification via la fonction existante
              await axios.post(sendNotificationFunctionUrl, {
                deviceTokens: deviceTokens,
                title: translate('bookingCancelled', userLanguage),
                body: translate('bookingCancelNotConfirmInTimeString', userLanguage),
                bookingId: bookingId,
                notificationType: 'BOOKING_EXPIRED',
              });

              logger.info(`📲 Notification sent to user ${userData.name} for expired booking ${bookingId}`);
            }
          }
        } catch (notifError) {
          logger.error(`Failed to send notification for booking ${bookingId}:`, notifError);
          // Continue même si la notification échoue
        }
      }

      // Exécuter toutes les mises à jour en batch
      await batch.commit();

      logger.info(`✅ Successfully cleaned up ${cleanedBookingIds.length} expired bookings: ${cleanedBookingIds.join(', ')}`);

      return {
        success: true,
        cleanedCount: cleanedBookingIds.length,
        bookingIds: cleanedBookingIds,
        timestamp: now.toDate(),
      };

    } catch (error) {
      logger.error('❌ Error in cleanupExpiredScheduledBookings:', error);
      throw error;
    }
  });

