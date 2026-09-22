.class public final Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;
.super Ljava/lang/Object;
.source "SourceFile"

# interfaces
.implements Landroid/content/DialogInterface$OnClickListener;


# instance fields
.field private final a:Lcom/dsemu/drastic/ui/Settings;

.field private final b:Z


# direct methods
.method public constructor <init>(Lcom/dsemu/drastic/ui/Settings;Z)V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;->a:Lcom/dsemu/drastic/ui/Settings;

    iput-boolean p2, p0, Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;->b:Z

    return-void
.end method


# virtual methods
.method public onClick(Landroid/content/DialogInterface;I)V
    .locals 4

    add-int/lit8 v0, p2, 0x1

    iget-boolean v1, p0, Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;->b:Z

    if-eqz v1, :hires_scale_global

    sput v0, Lf0/h;->Hires3DScaleGame:I

    const/4 v1, 0x1

    if-le v0, v1, :hires_game_native

    const/4 v2, 0x1

    goto :hires_game_bool

    :hires_game_native
    const/4 v2, 0x0

    :hires_game_bool
    sput-boolean v2, Lf0/h;->V0:Z

    iget-object v1, p0, Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;->a:Lcom/dsemu/drastic/ui/Settings;

    const v3, 0x7f0900f1

    invoke-virtual {v1, v3}, Landroid/app/Activity;->findViewById(I)Landroid/view/View;

    move-result-object v1

    if-eqz v1, :hires_game_refresh

    check-cast v1, Landroid/widget/CheckBox;

    invoke-virtual {v1, v2}, Landroid/widget/CompoundButton;->setChecked(Z)V

    :hires_game_refresh
    iget-object v1, p0, Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;->a:Lcom/dsemu/drastic/ui/Settings;

    invoke-static {v1}, Lcom/dsemu/drastic/ui/Settings;->refreshHiresGame(Lcom/dsemu/drastic/ui/Settings;)V

    goto :hires_scale_done

    :hires_scale_global
    sput v0, Lf0/h;->Hires3DScale:I

    const/4 v1, 0x1

    if-le v0, v1, :hires_global_native

    const/4 v2, 0x1

    goto :hires_global_bool

    :hires_global_native
    const/4 v2, 0x0

    :hires_global_bool
    sput-boolean v2, Lf0/h;->D0:Z

    iget-object v1, p0, Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;->a:Lcom/dsemu/drastic/ui/Settings;

    const v3, 0x7f0900f0

    invoke-virtual {v1, v3}, Landroid/app/Activity;->findViewById(I)Landroid/view/View;

    move-result-object v1

    if-eqz v1, :hires_global_refresh

    check-cast v1, Landroid/widget/CheckBox;

    invoke-virtual {v1, v2}, Landroid/widget/CompoundButton;->setChecked(Z)V

    :hires_global_refresh
    iget-object v1, p0, Lcom/dsemu/drastic/ui/Settings$HiresScaleListener;->a:Lcom/dsemu/drastic/ui/Settings;

    invoke-static {v1}, Lcom/dsemu/drastic/ui/Settings;->refreshHiresGlobal(Lcom/dsemu/drastic/ui/Settings;)V

    :hires_scale_done
    invoke-interface {p1}, Landroid/content/DialogInterface;->dismiss()V

    return-void
.end method
