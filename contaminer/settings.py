"""Contains the general settings for ContaMiner."""


# pylint: disable=too-few-public-methods
class Settings:
    """
    Load, provide, and set the global ContaMiner settings.

    Attributes
    ----------
    contabase_directory: string
        The full path to the directory containing the prepared models.

    morda_source: string
        The full path to the morda_env_sh script.

    ccp4_source: string
        The full path to the ccp4.setup-sh script.

    """

    contabase_directory = "/home/hunglea/ContaBase"
    morda_source = "/home/hungleaj/Morda_DB/morda_env_sh"
    ccp4_source = "/home/hungleaj/ccp4/bin/ccp4.setup-sh"
