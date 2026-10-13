"""Diagnósticos administrativos do app dono do servidor Lineage."""

from django.utils.translation import gettext_lazy
from drf_spectacular.utils import extend_schema
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.server.application.journey_bridge import GetJourneyBridgeStatusUseCase
from common.permissions import IsStaffMember
from common.views import InjectedAPIView


class JourneyBridgeStatusView(InjectedAPIView):
    """Expõe somente à equipe a saúde da ponte autenticada do L2Journey."""

    permission_classes = [IsAuthenticated, IsStaffMember]

    @extend_schema(
        tags=["Servidor"],
        summary=gettext_lazy("Diagnosticar ponte Journey"),
        description=gettext_lazy(
            "Verifica a comunicação autenticada entre o PDL e o GameServer Journey sem alterar personagens."
        ),
    )
    def get(self, request):
        return Response(self.resolve(GetJourneyBridgeStatusUseCase).execute())
