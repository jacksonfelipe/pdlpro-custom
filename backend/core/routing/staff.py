from django.urls import include, path

urlpatterns = [
    path("", include("apps.server.presentation.urls.staff")),
    path("", include("apps.staff.presentation.urls.staff")),
    path("support/", include("apps.support.presentation.urls.staff")),
]
