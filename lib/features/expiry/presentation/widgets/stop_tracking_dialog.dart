import 'package:flutter/material.dart';


Future<bool?> showStopTrackingDialog(
    BuildContext context,
) {

  return showDialog<bool>(

    context: context,


    builder: (context){

      return AlertDialog(

        title: const Text(
          "Stop Tracking?",
        ),


        content: const Text(

          "This will remove expiry reminders "
          "from monitoring.\n\n"
          "The food item will remain in your pantry.",

        ),



        actions: [

          TextButton(

            onPressed: (){

              Navigator.pop(
                context,
                false,
              );

            },


            child: const Text(
              "Cancel",
            ),

          ),



          ElevatedButton(

            onPressed: (){

              Navigator.pop(
                context,
                true,
              );

            },


            child: const Text(
              "Stop Tracking",
            ),

          ),

        ],

      );

    },

  );

}