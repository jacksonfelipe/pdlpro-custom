"""Rotas de equipe pertencentes ao app server."""

from django.urls import path

from apps.server.presentation.views.staff import JourneyBridgeStatusView

urlpatterns = [
    path("server/journey-bridge/", JourneyBridgeStatusView.as_view(), name="staff-journey-bridge"),
]
