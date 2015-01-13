package Gitpan::Role::HasBackpanIndex;

use Gitpan::perl5i;

use Moo::Role;
use Gitpan::Types;

with "Gitpan::Role::HasConfig";

has backpan_index =>
  is            => 'rw',
  isa           => InstanceOf['BackPAN::Index'],
  lazy          => 1,
  builder       => "default_backpan_index";

# Everybody share one index object.
method default_backpan_index {
    require BackPAN::Index;

    state $index;
    state $pid;

    # We can't pass active SQLite connections to the child.
    # Make a fresh BackPAN::Index object with a fresh connection.
    $index = do {
        $pid = $$;
        $self->_build_index;
    } if !$index || $pid != $$;

    return $index;
}

method _build_index {
    my $config = $self->config;

    my @opts;
    push @opts, (update => 1) if $config->backpan_always_update;

    push @opts, (normalize_dist_names => $config->backpan_normalize_dist_names)
      if keys %{$config->backpan_normalize_dist_names};
    push @opts, (normalize_releases   => $config->backpan_normalize_releases)
      if keys %{$config->backpan_normalize_releases};

    push @opts, (cache_dir => $config->backpan_cache_dir.'')
      if defined $config->backpan_cache_dir;

    push @opts, (backpan_index_url => $config->backpan_index_url)
      if defined $config->backpan_index_url;

    return BackPAN::Index->new(
        cache_ttl                       => $self->config->backpan_cache_ttl,
        releases_only_from_authors      => 1,
        @opts
    );
}
