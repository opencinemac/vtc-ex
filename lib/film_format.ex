defmodule Vtc.FilmFormat do
  @moduledoc """
  Functions and types for working with physical film data.
  """

  @typedoc """
  Enum-like type of supported film formats for Vtc.

  ## ff35mm_4perf

  35mm 4-perf film (16 frames per foot). ex: '5400+13'.

  ### What it is

  On physical film, each foot contains a certain number of frames. For 35mm, 4-perf film
  (the most common type on Hollywood movies), this number is 16 frames per foot.
  Feet-and-frames was often used in place of Keycode to quickly reference a frame in the
  edit.

  ### Where you see it

  For the most part, feet + frames has died out as a reference, because digital media is
  not measured in feet. The most common place it is still used is Studio Sound
  Departments. Many Sound Mixers and Designers intuitively think in feet + frames, and
  it is often burned into the reference picture for them.

  - Telecine.
  - Sound turnover reference picture.
  - Sound turnover change lists.

  ## ff35mm_2perf

  ### What it is

  35mm 2-perf film records 32 frames in a foot of film, instead of the usual 16.
  This creates a negative image with a wide aspect ratio using standard spherical
  lenses and consumes half the footage per minute running time as standard 35mm,
  while having a grain profile somewhat better than 16mm while not as good as
  standard 35mm.

  ### Where you see it

  35mm 2-perf formats are uncommon though still find occasional use, the process is
  usually marketed as "Techniscope", the original trademark for Technicolor Italia's
  2-perf format. It was historically very common in the Italian film industry prior
  to digital filmmaking, and is used on some contemporary films to obtain a film look
  while keeping stock and processing costs down.

  ## 16mm

  ### What it is

  On 16mm film, there are forty frames of film in each foot, one perforation
  per frame. However, 16mm film is edge coded every six inches, with twenty
  frames per code, so the footage "1+19" is succeeded by "2+0".

  ### Where you see it

  16mm telecines, 16mm edge codes.
  """
  @type t() :: :ff35mm_4perf | :ff35mm_2perf | :ff16mm

  @doc section: :perfs
  @doc """
  Perferations are the holes that run along the sides of a strip of film, and are used
  by the camera's sprocket to physically pull the film in place to be exposed. For
  more information, see [this Wikipedia atricle](https://en.wikipedia.org/wiki/Film_perforations#:~:text=Film%20perforations%2C%20also%20known%20as,film%20format%2C%20and%20intended%20usage).

  By default, returns the count in a 'logical' foot.

  > ### Logical feet and 16mm {: .warning}
  >
  > 'Logicial foot' means each time `XX` rolls over when annotated in the `XX+YY`
  > format. Threre are 40 perfs in a foot of 16mm film, but when annotated as `XX+YY`,
  > `XX` rolls over every 6 inches rather than every foot.

  ## Options

  - `physical?`: Return the physical number of feet rather than the logical number.
  """
  @spec perfs_per_foot(t(), physical?: boolean()) :: pos_integer()
  def perfs_per_foot(film_format, opts \\ [])
  def perfs_per_foot(film_format, _) when film_format in [:ff35mm_4perf, :ff35mm_2perf], do: 64
  def perfs_per_foot(:ff16mm, opts), do: if(Keyword.get(opts, :physical?), do: 40, else: 20)

  @doc section: :perfs
  @doc """
  Perferation count in a single frame of film.
  """
  @spec perfs_per_frame(t()) :: pos_integer()
  def perfs_per_frame(film_format)
  def perfs_per_frame(:ff35mm_4perf), do: 4
  def perfs_per_frame(:ff35mm_2perf), do: 2
  def perfs_per_frame(:ff16mm), do: 1
end
