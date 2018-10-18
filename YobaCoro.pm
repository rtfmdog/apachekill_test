package YobaCoro;

use 5.10.1;
use strict;
use warnings;

use base "Exporter";
our @EXPORT = qw/
   watcher coro pool sleep
/;
our @EXPORT_OK = @EXPORT;

use Coro;
use Coro::AnyEvent;
use Coro::LWP;
use AnyEvent;

sub sleep($)
{
   my($s) = @_;
   Coro::AnyEvent::sleep($s);
   return;
}

sub watcher()
{
   return AnyEvent->timer(
      interval => 2,
      cb => sub {
         my $time = time;
         map {
            say "YobaCoro: thread #$_->{id} ('$_->{desc}') terminated."
               if $_->{debug};
            $_->cancel(undef);
         } grep {
            $_->{timeout_at} && $time >= $_->{timeout_at}
         } reverse Coro::State::list;
      },
   );
}

sub coro($$;$)
{
   my($sub, $arg, $options_) = @_;
   $options_ ||= {};

   my $options = {
      debug   => 0,
      desc    => "anon",
      timeout => 0,
      eval    => 0,
      ready   => 0,
      join    => 0,
      %$options_,
   };

   state $id = 1;

   my $coro; $coro = Coro->new(sub {
      $coro->{id} = $id++;
      $coro->{desc} = $options->{desc};
      $coro->{timeout_at} = time + $options->{timeout}
         if $options->{timeout};
      $coro->{debug} = $options->{debug};

      say "YobaCoro: thread #$coro->{id} ('$coro->{desc}') started."
         if $options->{debug};

      my $result;
      if($options->{eval}) {
         eval { $result = $sub->($arg) };
         if($@ && $options->{debug}) {
            chomp $@;
            say "YobaCoro: thread #$coro->{id} ('$coro->{desc}') died: $@";
         }
      } else {
         $result = $sub->($arg);
      }

      say "YobaCoro: thread #$coro->{id} ('$coro->{desc}') finished."
         if $options->{debug};

      return $result // undef;
   });

   $coro->ready if $options->{ready} || $options->{join};
   return $options->{join} ? $coro->join : $coro;
}

sub pool($$;$)
{
   my($sub, $args, $options_) = @_;
   $options_ ||= {};

   my $options = {
      debug => 0,
      desc  => "anon",
      ready => 0,
      join  => 0,
      limit => 0,
      %$options_,
   };

   say "YobaCoro: create pool '$options->{desc}' with ".@$args." threads."
      if $options->{debug};

   my $pool = async
   {
      my @results;

      while(my @args_ = ($options->{limit} > 0 ? splice @$args, 0, $options->{limit} : splice @$args))
      {
         my @coros = map {
            coro($sub, $_, {
               %$options,
               desc  => "$options->{desc} pool",
               ready => 0,
               join  => 0,
            });
         } @args_;

         push @results, map { $_->join } map { $_->ready; $_ } @coros;
      }

      return @results;
   };

   $pool->ready if $options->{ready} || $options->{join};
   return $options->{join} ? $pool->join : $pool;
}

2;
