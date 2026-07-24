"""Idempotent non-production Authentik fixtures for the Docker simulation stack."""

import os
from datetime import UTC, datetime, timedelta

from django.db import transaction
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

from authentik.core.models import Application, Group, User
from authentik.crypto.models import CertificateKeyPair
from authentik.flows.models import Flow
from authentik.providers.oauth2.models import (
    ClientTypes,
    OAuth2Provider,
    RedirectURI,
    RedirectURIMatchingMode,
    ScopeMapping,
)


def required(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise RuntimeError(f"{name} is required")
    return value


def signing_key() -> CertificateKeyPair:
    existing = CertificateKeyPair.objects.filter(name="Microwave Drying Machine OIDC Signing").first()
    if existing is not None:
        return existing
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "mwd-authentik-simulation")])
    now = datetime.now(UTC)
    certificate = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(subject)
        .public_key(private_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=1))
        .not_valid_after(now + timedelta(days=3650))
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .sign(private_key, hashes.SHA256())
    )
    return CertificateKeyPair.objects.create(
        name="Microwave Drying Machine OIDC Signing",
        certificate_data=certificate.public_bytes(serialization.Encoding.PEM).decode(),
        key_data=private_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        ).decode(),
    )


@transaction.atomic
def bootstrap() -> None:
    groups = {name: Group.objects.get_or_create(name=name)[0] for name in ("viewer", "operator", "admin")}
    fixtures = (
        ("sim-admin", "MWD_SIM_ADMIN_PASSWORD", True, ("admin", "operator", "viewer")),
        ("sim-operator", "MWD_SIM_OPERATOR_PASSWORD", True, ("operator", "viewer")),
        ("sim-viewer", "MWD_SIM_VIEWER_PASSWORD", True, ("viewer",)),
        ("sim-disabled", "MWD_SIM_DISABLED_PASSWORD", False, ("viewer",)),
    )
    for username, password_env, active, memberships in fixtures:
        user, _ = User.objects.get_or_create(username=username, defaults={"name": username})
        user.name = username
        user.is_active = active
        user.set_password(required(password_env))
        user.save()
        user.ak_groups.set([groups[name] for name in memberships])

    authorization_flow = Flow.objects.get(slug="default-provider-authorization-implicit-consent")
    invalidation_flow = Flow.objects.get(slug="default-provider-invalidation-flow")
    oidc_signing_key = signing_key()
    provider, _ = OAuth2Provider.objects.update_or_create(
        name="Microwave Drying Machine",
        defaults={
            "authorization_flow": authorization_flow,
            "invalidation_flow": invalidation_flow,
            "client_type": ClientTypes.CONFIDENTIAL,
            "client_id": required("MWD_AUTHENTIK_CLIENT_ID"),
            "client_secret": required("MWD_AUTHENTIK_CLIENT_SECRET"),
            "signing_key": oidc_signing_key,
            "redirect_uris": [
                RedirectURI(
                    matching_mode=RedirectURIMatchingMode.STRICT,
                    url=required("MWD_AUTHENTIK_REDIRECT_URI"),
                ),
                RedirectURI(
                    matching_mode=RedirectURIMatchingMode.STRICT,
                    url=required("MWD_AUTHENTIK_POST_LOGOUT_REDIRECT_URI"),
                ),
            ],
        },
    )
    provider.property_mappings.set(
        ScopeMapping.objects.filter(scope_name__in=("openid", "profile", "email"))
    )
    Application.objects.update_or_create(
        slug="microwave-drying-machine",
        defaults={"name": "Microwave Drying Machine", "provider": provider},
    )
    for username, password_env, active, memberships in fixtures:
        user = User.objects.get(username=username)
        assert user.is_active is active
        assert user.check_password(required(password_env))
        assert set(user.ak_groups.values_list("name", flat=True)) == set(memberships)
    assert provider.client_id == required("MWD_AUTHENTIK_CLIENT_ID")
    assert provider.signing_key_id == oidc_signing_key.pk
    assert provider.signing_key.key_data
    assert provider.signing_key.certificate_data
    print("Authentik simulation users, groups, provider, and application are ready.")


bootstrap()
