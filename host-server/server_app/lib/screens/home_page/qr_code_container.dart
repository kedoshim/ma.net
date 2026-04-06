import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:server_app/theme/app_theme.dart';

Expanded connectionMethodsContainer(
  String connectionUrl, {
  required String qrCodeUrl,
}) {
  return Expanded(
    flex: 15,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Container(
            width: constraints.maxWidth * 0.95,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryText,
                width: 5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.primaryText,
                          width: 3,
                        ),
                      ),
                      child:  ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          qrCodeUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'link: $connectionUrl',
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodyMedium.copyWith(
                            fontFamily: 'pico',
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          FontAwesomeIcons.copy,
                          color: AppTheme.primaryText,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
